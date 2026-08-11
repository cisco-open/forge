"""Tests for the Splunk Data Manager log-group helper."""

from __future__ import annotations

from typing import Any

import pytest
from botocore.exceptions import ClientError
from support import load_handler_module

ACCOUNT_ID = '123456789012'
REGION = 'us-west-2'
PARTITION = 'aws'


@pytest.fixture(autouse=True)
def _scope_environment(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv('EXPECTED_ACCOUNT_ID', ACCOUNT_ID)
    monkeypatch.setenv('EXPECTED_PARTITION', PARTITION)
    monkeypatch.setenv('EXPECTED_REGION', REGION)
    monkeypatch.setenv('FUNCTION_NAME_PREFIX', 'SplunkDM')


def _stack_id(suffix: str, *, nested: bool = False) -> str:
    kind = 'Nested' if nested else 'DataIngest'
    return (
        f'arn:{PARTITION}:cloudformation:{REGION}:{ACCOUNT_ID}:'
        f'stack/SplunkDM{kind}-{suffix}/{suffix}'
    )


def _client_error(code: str, operation: str, message: str = '') -> ClientError:
    return ClientError(
        {'Error': {'Code': code, 'Message': message or code}},
        operation,
    )


class _Paginator:
    def __init__(self, pages_by_stack: dict[str, Any]):
        self.pages_by_stack = pages_by_stack

    def paginate(self, *, StackName: str):
        pages = self.pages_by_stack[StackName]
        if isinstance(pages, ClientError):
            raise pages
        for page in pages:
            yield {'StackResourceSummaries': page}


class _CloudFormation:
    def __init__(self, pages_by_stack: dict[str, Any]):
        self.pages_by_stack = pages_by_stack

    def get_paginator(self, operation: str) -> _Paginator:
        assert operation == 'list_stack_resources'
        return _Paginator(self.pages_by_stack)


class _Logs:
    def __init__(self, groups: set[str] | None = None):
        self.groups = groups or set()
        self.create_calls: list[str] = []
        self.tag_calls: list[tuple[str, dict[str, str]]] = []
        self.delete_calls: list[str] = []

    def create_log_group(self, *, logGroupName: str) -> None:
        self.create_calls.append(logGroupName)
        if logGroupName in self.groups:
            raise _client_error(
                'ResourceAlreadyExistsException',
                'CreateLogGroup',
            )
        self.groups.add(logGroupName)

    def tag_resource(
        self,
        *,
        resourceArn: str,
        tags: dict[str, str],
    ) -> None:
        self.tag_calls.append((resourceArn, tags))

    def delete_log_group(self, *, logGroupName: str) -> None:
        self.delete_calls.append(logGroupName)
        if logGroupName not in self.groups:
            raise _client_error('ResourceNotFoundException', 'DeleteLogGroup')
        self.groups.remove(logGroupName)


def _lambda_resource(logical_id: str, physical_name: str) -> dict[str, str]:
    return {
        'ResourceType': 'AWS::Lambda::Function',
        'LogicalResourceId': logical_id,
        'PhysicalResourceId': physical_name,
    }


def _delete_event(function_name: str) -> dict[str, Any]:
    return {
        'source': 'aws.lambda',
        'detail-type': 'AWS API Call via CloudTrail',
        'account': ACCOUNT_ID,
        'region': REGION,
        'detail': {
            'eventSource': 'lambda.amazonaws.com',
            'eventName': 'DeleteFunction20150331',
            'requestParameters': {'functionName': function_name},
        },
    }


def test_reconcile_uses_physical_name_from_nested_paginated_stack():
    mod = load_handler_module('splunk_dm_log_group_reconciler')
    root_stack = _stack_id('root')
    nested_stack = _stack_id('child', nested=True)
    function_name = 'SplunkDMTaggingLambda1234'
    cloudformation = _CloudFormation({
        root_stack: [
            [{'ResourceType': 'AWS::S3::Bucket'}],
            [{
                'ResourceType': 'AWS::CloudFormation::Stack',
                'LogicalResourceId': 'ProcessorStack',
                'PhysicalResourceId': nested_stack,
            }],
        ],
        nested_stack: [[
            _lambda_resource('CustomLogsEventProcessor', function_name),
        ]],
    })
    logs = _Logs()

    result = mod.reconcile(
        {
            'region': REGION,
            'stack_ids': [root_stack],
            'tags': {'Environment': 'prod', 'TeamName': 'forge'},
        },
        cloudformation,
        logs,
    )

    group_name = f'/aws/lambda/{function_name}'
    assert logs.create_calls == [group_name]
    assert logs.tag_calls == [(
        f'arn:aws:logs:{REGION}:{ACCOUNT_ID}:log-group:{group_name}',
        {'Environment': 'prod', 'TeamName': 'forge'},
    )]
    assert result == {
        'action': 'reconcile',
        'functions': 1,
        'log_groups_created': 1,
        'log_groups_tagged': 1,
    }


def test_reconcile_updates_tags_on_an_existing_log_group():
    mod = load_handler_module('splunk_dm_log_group_reconciler')
    stack_id = _stack_id('existing')
    function_name = 'SplunkDMExistingLambda1234'
    group_name = f'/aws/lambda/{function_name}'
    logs = _Logs({group_name})

    result = mod.reconcile(
        {
            'stack_ids': [stack_id],
            'tags': {'Environment': 'prod'},
        },
        _CloudFormation({
            stack_id: [[_lambda_resource('Processor', function_name)]],
        }),
        logs,
    )

    assert logs.create_calls == [group_name]
    assert logs.tag_calls[0][1] == {'Environment': 'prod'}
    assert result['log_groups_created'] == 0
    assert result['log_groups_tagged'] == 1


def test_delete_event_removes_the_exact_function_log_group():
    mod = load_handler_module('splunk_dm_log_group_reconciler')
    function_name = 'SplunkDMDeleteLambda1234'
    group_name = f'/aws/lambda/{function_name}'
    logs = _Logs({group_name})

    result = mod.delete_log_group(
        _delete_event(function_name),
        logs,
    )

    assert logs.delete_calls == [group_name]
    assert result['deleted'] is True
    assert result['log_group_name'] == group_name


def test_delete_event_accepts_scoped_arn_and_is_idempotent():
    mod = load_handler_module('splunk_dm_log_group_reconciler')
    function_name = 'SplunkDMMissingLambda1234'
    function_arn = (
        f'arn:{PARTITION}:lambda:{REGION}:{ACCOUNT_ID}:'
        f'function:{function_name}'
    )
    logs = _Logs()

    result = mod.delete_log_group(
        _delete_event(function_arn),
        logs,
    )

    assert logs.delete_calls == [f'/aws/lambda/{function_name}']
    assert result['deleted'] is False


@pytest.mark.parametrize(
    'event',
    [
        {**_delete_event('SplunkDMFunction'), 'account': '999999999999'},
        {**_delete_event('SplunkDMFunction'), 'region': 'us-east-1'},
        _delete_event('UnmanagedFunction'),
        {
            **_delete_event('SplunkDMFunction'),
            'detail': {
                **_delete_event('SplunkDMFunction')['detail'],
                'errorCode': 'AccessDeniedException',
            },
        },
        {
            **_delete_event('SplunkDMFunction'),
            'detail': {
                **_delete_event('SplunkDMFunction')['detail'],
                'requestParameters': {
                    'functionName': 'SplunkDMFunction',
                    'qualifier': '1',
                },
            },
        },
    ],
)
def test_delete_event_rejects_resources_outside_its_scope(event):
    mod = load_handler_module('splunk_dm_log_group_reconciler')
    logs = _Logs({'/aws/lambda/SplunkDMFunction'})

    with pytest.raises(ValueError):
        mod.delete_log_group(event, logs)

    assert logs.delete_calls == []


def test_invalid_stack_scope_and_cloudformation_errors_propagate():
    mod = load_handler_module('splunk_dm_log_group_reconciler')
    stack_id = _stack_id('invalid').replace(REGION, 'us-east-1')
    with pytest.raises(ValueError, match='outside the helper scope'):
        mod.discover_function_names(
            [stack_id],
            _CloudFormation({}),
        )

    stack_id = _stack_id('denied')
    with pytest.raises(ClientError):
        mod.discover_function_names(
            [stack_id],
            _CloudFormation({
                stack_id: _client_error('AccessDenied', 'ListStackResources'),
            }),
        )
