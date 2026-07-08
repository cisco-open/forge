"""Forge trust preparer/validator workflow tests."""

from __future__ import annotations

import json

import pytest
from botocore.exceptions import ClientError
from conftest import requires_aws
from support import load_handler_module

pytestmark = [pytest.mark.isolation, requires_aws]

FORGE_ROLE = 'arn:aws:iam::123456789012:role/forge-role'
TENANT_ROLE = 'arn:aws:iam::111111111111:role/tenant-role'
VALIDATOR_ROLE = 'arn:aws:iam::123456789012:role/validator'


def test_build_validation_payload_has_expected_contract(monkeypatch, aws):
    mod = load_handler_module('trust_preparer')
    monkeypatch.setattr(mod.time, 'time', lambda: 1234567890)

    payload = mod.build_validation_payload(
        'run-1',
        [FORGE_ROLE],
        [TENANT_ROLE],
    )

    assert payload == {
        'phase': 'validate',
        'run_id': 'run-1',
        'created_at_epoch': 1234567890,
        'forge_role_arns': [FORGE_ROLE],
        'tenant_role_arns': [TENANT_ROLE],
    }


def test_prepare_cleanup_runs_only_for_roles_already_prepared(
    monkeypatch, aws
):
    mod = load_handler_module('trust_preparer')
    prepared = []
    cleanup_calls = []

    def _prepare(forge_role_arn, lambda_role_arn):
        assert lambda_role_arn == VALIDATOR_ROLE
        if forge_role_arn.endswith('/two'):
            raise RuntimeError('iam update failed')
        prepared.append(forge_role_arn)

    monkeypatch.setattr(mod, 'prepare_temporary_forge_role_trust', _prepare)
    monkeypatch.setattr(
        mod,
        'cleanup_forge_roles',
        lambda roles: cleanup_calls.append(list(roles)) or [],
    )

    with pytest.raises(RuntimeError, match='iam update failed'):
        mod.prepare_forge_roles_for_delayed_validation(
            forge_role_arns=[
                'arn:aws:iam::123456789012:role/one',
                'arn:aws:iam::123456789012:role/two',
            ],
            tenant_role_arns=[TENANT_ROLE],
            validator_lambda_role_arn=VALIDATOR_ROLE,
            queue_url='https://sqs.example/queue',
            delay_seconds=30,
            run_id='run-1',
        )

    assert prepared == ['arn:aws:iam::123456789012:role/one']
    assert cleanup_calls == [['arn:aws:iam::123456789012:role/one']]


def test_trust_policy_update_replaces_stale_validator_statement(
    monkeypatch, aws
):
    mod = load_handler_module('trust_common')
    stale_policy = {
        'Version': '2012-10-17',
        'Statement': [
            {
                'Sid': 'KeepExisting',
                'Effect': 'Allow',
                'Principal': {'Service': 'ec2.amazonaws.com'},
                'Action': 'sts:AssumeRole',
            },
            {
                'Sid': mod.TRUST_STATEMENT_SID,
                'Effect': 'Allow',
                'Principal': {'AWS': 'arn:aws:iam::123456789012:role/old'},
                'Action': 'sts:AssumeRole',
            },
        ],
    }

    updated = mod.build_temporary_forge_trust_policy(
        stale_policy,
        VALIDATOR_ROLE,
    )

    assert updated['Statement'] == [
        {
            'Sid': 'KeepExisting',
            'Effect': 'Allow',
            'Principal': {'Service': 'ec2.amazonaws.com'},
            'Action': 'sts:AssumeRole',
        },
        {
            'Sid': mod.TRUST_STATEMENT_SID,
            'Effect': 'Allow',
            'Principal': {'AWS': VALIDATOR_ROLE},
            'Action': 'sts:AssumeRole',
        },
    ]
    assert mod.policy_has_validator_trust(updated, VALIDATOR_ROLE)


def test_call_with_backoff_retries_retryable_client_error(monkeypatch, aws):
    mod = load_handler_module('trust_common')
    attempts = []
    sleeps = []
    monkeypatch.setattr(mod.random, 'uniform', lambda _start, _end: 0.0)
    monkeypatch.setattr(mod.time, 'sleep',
                        lambda seconds: sleeps.append(seconds))

    def _operation():
        attempts.append('call')
        if len(attempts) == 1:
            raise ClientError({
                'Error': {
                    'Code': 'ThrottlingException',
                    'Message': 'Rate exceeded',
                },
            }, 'AssumeRole')
        return {'ok': True}

    result = mod.call_with_backoff(
        'assume test role',
        _operation,
        max_attempts=3,
    )

    assert result == {'ok': True}
    assert attempts == ['call', 'call']
    assert sleeps == [2.0]


def test_call_with_backoff_does_not_retry_permission_denied_by_default(
    monkeypatch, aws
):
    mod = load_handler_module('trust_common')
    sleeps = []
    monkeypatch.setattr(mod.time, 'sleep',
                        lambda seconds: sleeps.append(seconds))

    def _operation():
        raise ClientError({
            'Error': {
                'Code': 'AccessDenied',
                'Message': 'not authorized',
            },
        }, 'AssumeRole')

    with pytest.raises(ClientError) as exc:
        mod.call_with_backoff(
            'assume denied role',
            _operation,
            max_attempts=3,
        )

    assert exc.value.response['Error']['Code'] == 'AccessDenied'
    assert sleeps == []


def test_access_denied_retry_is_opt_in_for_eventual_consistency(
    monkeypatch, aws
):
    mod = load_handler_module('trust_common')
    err = ClientError({
        'Error': {
            'Code': 'AccessDenied',
            'Message': 'not authorized',
        },
    }, 'AssumeRole')

    assert not mod.is_retryable_client_error(err)
    assert mod.is_retryable_client_error(err, retry_access_denied=True)


def test_parse_env_int_enforces_bounds(monkeypatch, aws):
    mod = load_handler_module('trust_common')

    monkeypatch.setenv('VALIDATION_DELAY_SECONDS', '900')
    assert mod.parse_env_int('VALIDATION_DELAY_SECONDS', 300, 0, 900) == 900

    monkeypatch.setenv('VALIDATION_DELAY_SECONDS', '901')
    with pytest.raises(RuntimeError, match='between 0 and 900'):
        mod.parse_env_int('VALIDATION_DELAY_SECONDS', 300, 0, 900)

    monkeypatch.setenv('VALIDATION_DELAY_SECONDS', 'not-an-int')
    with pytest.raises(RuntimeError, match='must be an integer'):
        mod.parse_env_int('VALIDATION_DELAY_SECONDS', 300, 0, 900)


def test_parse_env_list_accepts_json_csv_and_malformed_json_fallback(
    monkeypatch, aws
):
    mod = load_handler_module('trust_common')

    monkeypatch.setenv('FORGE_IAM_ROLES', json.dumps([
        FORGE_ROLE,
        '',
        '  arn:aws:iam::123456789012:role/other  ',
    ]))
    assert mod.parse_env_list('FORGE_IAM_ROLES') == [
        FORGE_ROLE,
        'arn:aws:iam::123456789012:role/other',
    ]

    monkeypatch.setenv('FORGE_IAM_ROLES', f' {FORGE_ROLE},, {VALIDATOR_ROLE} ')
    assert mod.parse_env_list('FORGE_IAM_ROLES') == [
        FORGE_ROLE,
        VALIDATOR_ROLE,
    ]

    monkeypatch.setenv('FORGE_IAM_ROLES', '[not-json')
    assert mod.parse_env_list('FORGE_IAM_ROLES') == ['[not-json']


def test_normalize_policy_document_rejects_invalid_shapes(monkeypatch, aws):
    mod = load_handler_module('trust_common')

    with pytest.raises(ValueError, match='must be a JSON object'):
        mod.normalize_policy_document([])

    with pytest.raises(ValueError, match='Statement must be a list or object'):
        mod.normalize_policy_document({'Statement': 'not-a-statement'})


def test_wait_for_temporary_trust_retries_until_statement_visible(
    monkeypatch, aws
):
    mod = load_handler_module('trust_common')
    policies = [
        {'Statement': []},
        {
            'Statement': [
                mod.build_lambda_trust_statement(VALIDATOR_ROLE),
            ],
        },
    ]
    sleeps = []

    monkeypatch.setattr(
        mod,
        'get_role_assume_policy',
        lambda _role_name: policies.pop(0),
    )
    monkeypatch.setattr(mod.time, 'sleep',
                        lambda seconds: sleeps.append(seconds))

    result = mod.wait_for_temporary_forge_role_trust(
        'forge-role',
        VALIDATOR_ROLE,
    )

    assert mod.policy_has_validator_trust(result, VALIDATOR_ROLE)
    assert sleeps == [2.0]


def test_wait_for_temporary_trust_raises_when_statement_never_visible(
    monkeypatch, aws
):
    mod = load_handler_module('trust_common')
    sleeps = []
    monkeypatch.setattr(
        mod,
        'get_role_assume_policy',
        lambda _role_name: {'Statement': []},
    )
    monkeypatch.setattr(mod.time, 'sleep',
                        lambda seconds: sleeps.append(seconds))
    monkeypatch.setattr(mod, 'TRUST_POLICY_VERIFY_MAX_ATTEMPTS', 2)

    with pytest.raises(RuntimeError, match='Temporary trust statement'):
        mod.wait_for_temporary_forge_role_trust('forge-role', VALIDATOR_ROLE)

    assert sleeps == [2.0]


def test_session_policy_only_allows_tenant_assume_and_tag(monkeypatch, aws):
    mod = load_handler_module('trust_common')

    policy = json.loads(mod.build_session_policy_for_tenants([
        TENANT_ROLE,
        'arn:aws:iam::222222222222:role/tenant-two',
    ]))

    assert policy == {
        'Version': '2012-10-17',
        'Statement': [
            {
                'Sid': 'AllowAssumeTenantRolesForValidation',
                'Effect': 'Allow',
                'Action': [
                    'sts:AssumeRole',
                    'sts:TagSession',
                ],
                'Resource': [
                    TENANT_ROLE,
                    'arn:aws:iam::222222222222:role/tenant-two',
                ],
            }
        ],
    }
    assert policy['Statement'][0]['Resource'] != '*'


def test_remove_temporary_forge_role_trust_updates_when_present(
    monkeypatch, aws
):
    mod = load_handler_module('trust_common')
    current_policy = {
        'Statement': [
            {
                'Sid': mod.TRUST_STATEMENT_SID,
                'Effect': 'Allow',
                'Principal': {'AWS': VALIDATOR_ROLE},
                'Action': 'sts:AssumeRole',
            },
        ],
    }
    updates = []
    monkeypatch.setattr(
        mod,
        'get_role_assume_policy',
        lambda _role_name: current_policy,
    )
    monkeypatch.setattr(
        mod,
        'update_assume_role_policy',
        lambda role_name, policy: updates.append((role_name, policy)),
    )

    assert mod.remove_temporary_forge_role_trust('forge-role')
    assert updates == [(
        'forge-role',
        {'Version': '2012-10-17', 'Statement': []},
    )]


def test_prepare_handler_reads_env_and_schedules_validation(monkeypatch, aws):
    mod = load_handler_module('trust_preparer')
    for key, value in {
        'FORGE_IAM_ROLES': json.dumps([FORGE_ROLE]),
        'TENANT_IAM_ROLES': TENANT_ROLE,
        'VALIDATOR_LAMBDA_ROLE_ARN': VALIDATOR_ROLE,
        'VALIDATION_QUEUE_URL': 'https://sqs.example/queue',
        'VALIDATION_DELAY_SECONDS': '7',
    }.items():
        monkeypatch.setenv(key, value)
    captured = {}
    monkeypatch.setattr(mod, 'get_lambda_caller_identity', lambda: {})

    def _prepare(**kwargs):
        captured.update(kwargs)
        return {
            'phase': 'prepare',
            'run_id': kwargs['run_id'],
            'prepared_forge_role_arns': kwargs['forge_role_arns'],
        }

    monkeypatch.setattr(
        mod, 'prepare_forge_roles_for_delayed_validation', _prepare)

    class _Context:
        aws_request_id = 'request-123'

    result = mod.prepare_handler({}, _Context())

    assert result['statusCode'] == 200
    assert json.loads(result['body']) == {
        'phase': 'prepare',
        'run_id': 'request-123',
        'prepared_forge_role_arns': [FORGE_ROLE],
    }
    assert captured['delay_seconds'] == 7
    assert captured['tenant_role_arns'] == [TENANT_ROLE]


def test_is_sqs_event_requires_records_from_sqs(monkeypatch, aws):
    mod = load_handler_module('trust_validator')

    assert mod.is_sqs_event({
        'Records': [{'eventSource': 'aws:sqs'}],
    })
    assert not mod.is_sqs_event({'Records': []})
    assert not mod.is_sqs_event({'Records': [{'eventSource': 'aws:s3'}]})
    assert not mod.is_sqs_event(None)


def test_handle_sqs_event_rejects_wrong_phase(monkeypatch, aws):
    mod = load_handler_module('trust_validator')

    with pytest.raises(RuntimeError, match='Unsupported SQS validation phase'):
        mod.handle_sqs_event({
            'Records': [
                {
                    'eventSource': 'aws:sqs',
                    'body': json.dumps({'phase': 'prepare'}),
                }
            ],
        })


def test_validate_prepared_forge_roles_cleans_up_after_validation(
    monkeypatch, aws
):
    mod = load_handler_module('trust_validator')
    cleanup_calls = []
    monkeypatch.setattr(
        mod,
        'validate_prepared_forge_role_against_tenants',
        lambda forge_role_arn, tenant_role_arns: {
            'forge_role_arn': forge_role_arn,
            'tenant_results': tenant_role_arns,
            'errors': [],
        },
    )
    monkeypatch.setattr(
        mod,
        'cleanup_forge_roles',
        lambda roles: cleanup_calls.append(list(roles)) or [
            {'forge_role_arn': role, 'temporary_trust_policy_removed': True}
            for role in roles
        ],
    )

    result = mod.validate_prepared_forge_roles({
        'run_id': 'run-1',
        'forge_role_arns': [FORGE_ROLE, ''],
        'tenant_role_arns': [TENANT_ROLE, ''],
    })

    assert result['run_id'] == 'run-1'
    assert result['validation_results'] == [{
        'forge_role_arn': FORGE_ROLE,
        'tenant_results': [TENANT_ROLE],
        'errors': [],
    }]
    assert cleanup_calls == [[FORGE_ROLE]]
    assert result['cleanup_results'] == [{
        'forge_role_arn': FORGE_ROLE,
        'temporary_trust_policy_removed': True,
    }]


def test_validate_prepared_forge_role_records_tenant_failures(
    monkeypatch, aws
):
    mod = load_handler_module('trust_validator')
    forge_creds = {
        'AccessKeyId': 'access',
        'SecretAccessKey': 'secret',
        'SessionToken': 'token',
    }
    tenant_creds = {
        'AccessKeyId': 'tenant-access',
        'SecretAccessKey': 'tenant-secret',
        'SessionToken': 'tenant-token',
    }

    monkeypatch.setattr(
        mod,
        'assume_role',
        lambda **_kwargs: {'Credentials': forge_creds},
    )

    class _ForgeSts:
        def assume_role(self, **kwargs):
            if kwargs['RoleArn'].endswith('/denied'):
                raise ClientError({
                    'Error': {
                        'Code': 'AccessDenied',
                        'Message': 'not authorized',
                    },
                }, 'AssumeRole')
            if kwargs['RoleSessionName'] == 'TenantValidation-Tags':
                raise ClientError({
                    'Error': {
                        'Code': 'AccessDenied',
                        'Message': 'tag session denied',
                    },
                }, 'AssumeRole')
            return {'Credentials': tenant_creds}

    monkeypatch.setattr(
        mod,
        'build_sts_client_from_creds',
        lambda creds: _ForgeSts() if creds == forge_creds else None,
    )

    result = mod.validate_prepared_forge_role_against_tenants(
        FORGE_ROLE,
        [
            'arn:aws:iam::111111111111:role/tag-denied',
            'arn:aws:iam::111111111111:role/denied',
        ],
    )

    assert result['errors'] == []
    assert result['tenant_results'][0]['assume_role_success']
    assert not result['tenant_results'][0]['tag_session_success']
    assert 'AccessDenied' in result['tenant_results'][0]['tag_session_error']
    assert not result['tenant_results'][1]['assume_role_success']
    assert result['tenant_results'][1]['tag_session_error'] == (
        'Skipped because basic AssumeRole failed'
    )


def test_validate_handler_accepts_only_sqs_validation_events(monkeypatch, aws):
    mod = load_handler_module('trust_validator')
    monkeypatch.setattr(mod, 'get_lambda_caller_identity', lambda: {})
    monkeypatch.setattr(
        mod,
        'handle_sqs_event',
        lambda event: [{
            'run_id': json.loads(event['Records'][0]['body'])['run_id'],
        }],
    )

    result = mod.validate_handler({
        'Records': [
            {
                'eventSource': 'aws:sqs',
                'body': json.dumps({'phase': 'validate', 'run_id': 'run-1'}),
            }
        ],
    }, None)

    assert result['statusCode'] == 200
    assert json.loads(result['body']) == [{'run_id': 'run-1'}]

    with pytest.raises(RuntimeError, match='only accepts SQS'):
        mod.validate_handler({'Records': [{'eventSource': 'aws:s3'}]}, None)
