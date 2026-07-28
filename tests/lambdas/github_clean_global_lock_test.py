"""GitHub global lock cleanup Lambda tests."""

from __future__ import annotations

import base64
import json
import logging

import boto3
import requests
from conftest import AWS_REGION, requires_aws
from support import load_handler_module

pytestmark = requires_aws

TABLE_NAME = 'forge-global-lock-test'


def _create_lock_table():
    client = boto3.client('dynamodb', region_name=AWS_REGION)
    client.create_table(
        TableName=TABLE_NAME,
        AttributeDefinitions=[
            {'AttributeName': 'lock_id', 'AttributeType': 'S'},
        ],
        KeySchema=[{'AttributeName': 'lock_id', 'KeyType': 'HASH'}],
        BillingMode='PAY_PER_REQUEST',
    )
    return boto3.resource('dynamodb', region_name=AWS_REGION).Table(TABLE_NAME)


def _load_lock_lambda(monkeypatch):
    monkeypatch.setenv('DYNAMODB_TABLE', TABLE_NAME)
    return load_handler_module('github_clean_global_lock')


def test_parse_github_url_accepts_workflow_run_url(monkeypatch, aws):
    mod = _load_lock_lambda(monkeypatch)

    assert mod.parse_github_url(
        'https://github.com/acme/app/actions/runs/123456'
    ) == ('acme', 'app', '123456')


def test_parse_github_url_returns_empty_parts_for_invalid_url(
    monkeypatch, aws
):
    mod = _load_lock_lambda(monkeypatch)

    assert mod.parse_github_url('https://example.com/not-github') == (
        None,
        None,
        None,
    )


def test_scan_and_process_deletes_only_completed_workflow_locks(
    monkeypatch, aws, caplog
):
    caplog.set_level(logging.INFO)
    table = _create_lock_table()
    mod = _load_lock_lambda(monkeypatch)
    table.put_item(Item={
        'lock_id': 'lock-complete',
        'workflow_run_url': 'https://github.com/acme/app/actions/runs/100',
        'workflow_run_attempt': '1',
    })
    table.put_item(Item={
        'lock_id': 'lock-active',
        'workflow_run_url': 'https://github.com/acme/app/actions/runs/101',
        'workflow_run_attempt': '1',
    })
    table.put_item(Item={
        'lock_id': 'lock-invalid-url',
        'workflow_run_url': 'https://example.com/not-github',
        'workflow_run_attempt': '1',
    })

    def _status(_token, _owner, _repo, run_id, _attempt):
        return 'completed' if run_id == '100' else 'in_progress'

    monkeypatch.setattr(mod, 'get_workflow_status', _status)

    mod.scan_and_process_dynamodb('installation-token')

    remaining = {
        item['lock_id']
        for item in table.scan()['Items']
    }
    assert remaining == {'lock-active', 'lock-invalid-url'}
    assert (
        'global_lock_cleanup_deleted lock_id=lock-complete '
        'repository=acme/app run_id=100 attempt=1'
    ) in caplog.text
    assert (
        'global_lock_cleanup_observed lock_id=lock-active '
        'repository=acme/app run_id=101 attempt=1 status=in_progress'
    ) in caplog.text
    assert (
        'global_lock_cleanup_skipped reason=invalid_workflow_url '
        'lock_id=lock-invalid-url'
    ) in caplog.text


def test_get_workflow_status_returns_none_on_non_200(monkeypatch, aws):
    mod = _load_lock_lambda(monkeypatch)

    class _Response:
        status_code = 500

        def json(self):
            return {'status': 'completed'}

    monkeypatch.setattr(mod.GITHUB_SESSION, 'get', lambda *_args,
                        **_kwargs: _Response())

    assert mod.get_workflow_status(
        'token',
        'acme',
        'app',
        '100',
        '1',
    ) is None


def test_github_requests_retry_transient_failures(monkeypatch, aws):
    mod = _load_lock_lambda(monkeypatch)

    retries = mod.GITHUB_SESSION.get_adapter('https://').max_retries

    assert retries.total == 3
    assert retries.connect == 3
    assert retries.read == 3
    assert retries.status == 3
    assert retries.allowed_methods == frozenset({'GET', 'POST'})
    assert set(retries.status_forcelist) == {429, 500, 502, 503, 504}


def test_scan_continues_after_github_connection_error(
    monkeypatch, aws, caplog
):
    table = _create_lock_table()
    mod = _load_lock_lambda(monkeypatch)
    for lock_id, run_id in (
        ('lock-connection-error', '100'),
        ('lock-complete', '101'),
    ):
        table.put_item(Item={
            'lock_id': lock_id,
            'workflow_run_url': (
                f'https://github.com/acme/app/actions/runs/{run_id}'
            ),
            'workflow_run_attempt': '1',
        })

    def _status(_token, _owner, _repo, run_id, _attempt):
        if run_id == '100':
            raise requests.ConnectionError(
                'Remote end closed connection without response'
            )
        return 'completed'

    monkeypatch.setattr(mod, 'get_workflow_status', _status)

    mod.scan_and_process_dynamodb('installation-token')

    remaining = {
        item['lock_id']
        for item in table.scan()['Items']
    }
    assert remaining == {'lock-connection-error'}
    assert (
        'global_lock_cleanup_lookup_failed '
        'lock_id=lock-connection-error repository=acme/app run_id=100'
    ) in caplog.text


def test_lambda_handler_loads_ssm_secrets_and_runs_cleanup(monkeypatch, ssm):
    _create_lock_table()
    mod = _load_lock_lambda(monkeypatch)
    for name, value in {
        '/forge/app_id': '12345',
        '/forge/private_key': base64.b64encode(b'FAKE-KEY').decode(),
        '/forge/installation_id': '999',
    }.items():
        ssm['client'].put_parameter(
            Name=name, Value=value, Type='SecureString')

    for key, value in {
        'SECRET_NAME_APP_ID': '/forge/app_id',
        'SECRET_NAME_PRIVATE_KEY': '/forge/private_key',
        'SECRET_NAME_INSTALLATION_ID': '/forge/installation_id',
    }.items():
        monkeypatch.setenv(key, value)

    calls = []
    monkeypatch.setattr(mod, 'generate_jwt', lambda app_id, key: 'jwt-token')
    monkeypatch.setattr(
        mod,
        'get_installation_access_token',
        lambda jwt_token, installation_id: 'installation-token',
    )
    monkeypatch.setattr(
        mod,
        'scan_and_process_dynamodb',
        lambda token: calls.append(token),
    )

    result = mod.lambda_handler({}, None)

    assert result['statusCode'] == 200
    assert json.loads(result['body']) == {
        'message': 'Cleaned lock successfully.'
    }
    assert calls == ['installation-token']
