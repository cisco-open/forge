"""Splunk stuck workflow-job worker Lambda tests."""

from __future__ import annotations

import base64
import importlib
import json
import sys
from pathlib import Path
from types import SimpleNamespace

import boto3
import pytest
from botocore.exceptions import ClientError
from conftest import requires_aws

pytestmark = requires_aws

LAMBDA_DIR = Path(__file__).resolve().parents[2].joinpath(
    'modules',
    'integrations',
    'splunk_stuck_workflow_job_dispatcher',
    'lambda',
)


def _load_worker(monkeypatch):
    src = str(LAMBDA_DIR)
    if src not in sys.path:
        sys.path.insert(0, src)
    monkeypatch.setenv('DEDUPE_TABLE', 'splunk-worker-test')
    sys.modules.pop('worker', None)
    return importlib.import_module('worker')


def test_normalize_private_key_decodes_base64_pem(monkeypatch, aws):
    mod = _load_worker(monkeypatch)
    key_label = 'PRIVATE KEY'
    pem = (
        f'-----BEGIN {key_label}-----\n'
        'abc123\n'
        f'-----END {key_label}-----'
    )
    encoded = base64.b64encode(pem.encode()).decode()

    assert mod.normalize_private_key(encoded) == pem


def test_create_github_app_jwt_uses_pyjwt_rs256(monkeypatch, aws):
    mod = _load_worker(monkeypatch)
    calls = []
    monkeypatch.setattr(mod.time, 'time', lambda: 2000)

    def _encode(payload, key, algorithm):
        calls.append((payload, key, algorithm))
        return 'jwt-token'

    monkeypatch.setitem(sys.modules, 'jwt', SimpleNamespace(encode=_encode))

    assert mod.create_github_app_jwt('app-client-id', 'pem-key') == 'jwt-token'
    assert calls == [
        (
            {'iat': 1940, 'exp': 2540, 'iss': 'app-client-id'},
            'pem-key',
            'RS256',
        ),
    ]


def test_github_request_uses_requests(monkeypatch, aws):
    mod = _load_worker(monkeypatch)
    calls = []

    def _request(method, url, headers, json, timeout):
        calls.append((method, url, headers, json, timeout))
        return SimpleNamespace(
            status_code=404,
            headers={'X-GitHub-Request-Id': 'abc123'},
            content=b'not found',
        )

    monkeypatch.setitem(sys.modules, 'requests',
                        SimpleNamespace(request=_request))

    status, headers, body = mod.github_request(
        'jwt-token',
        'POST',
        '/app/hook/deliveries/1/attempts',
        body={'redeliver': True},
        api_url='https://api.github.test',
        api_version='2022-11-28',
    )

    assert status == 404
    assert headers == {'x-github-request-id': 'abc123'}
    assert body == b'not found'
    assert calls == [
        (
            'POST',
            'https://api.github.test/app/hook/deliveries/1/attempts',
            {
                'Accept': 'application/vnd.github+json',
                'Authorization': 'Bearer jwt-token',
                'Content-Type': 'application/json',
                'User-Agent': 'forge-stuck-workflow-job-redelivery',
                'X-GitHub-Api-Version': '2022-11-28',
            },
            {'redeliver': True},
            30,
        ),
    ]


def test_normalize_delivery_ids_dedupes_numeric_ids(monkeypatch, aws):
    mod = _load_worker(monkeypatch)

    ids = mod.normalize_delivery_ids([
        '123',
        ' 123 ',
        '456',
        '456',
        '',
    ])

    assert ids == ['123', '456']


def test_normalize_delivery_ids_rejects_invalid_value(monkeypatch, aws):
    mod = _load_worker(monkeypatch)

    with pytest.raises(ValueError, match='Invalid delivery ID'):
        mod.normalize_delivery_ids(['not-a-delivery-reference'])


def test_delivery_rows_uses_splunk_delivery_ids(monkeypatch, aws):
    mod = _load_worker(monkeypatch)

    rows = mod.delivery_rows({'github_delivery': ['123', '456']})

    assert [row['id'] for row in rows] == ['123', '456']


def test_resolve_tenant_config_uses_matching_tenant_and_region(
    monkeypatch, aws
):
    mod = _load_worker(monkeypatch)
    mod.tenant_configs_cache = [
        {
            'tenant': 'acgw',
            'github_api': 'https://github.example/api/v3',
            'github_api_version': '2023-01-01',
            'prefixes': [
                {
                    'aws_region': 'us-west-2',
                    'deployment_prefix': 'acgw-usw2',
                },
            ],
        },
    ]

    config = mod.resolve_tenant_config({
        'tenant': 'acgw',
        'aws_region': 'us-west-2',
    })

    assert config == {
        'deployment_prefix': 'acgw-usw2',
        'github_api_url': 'https://github.example/api/v3',
        'github_api_version': '2023-01-01',
    }


def test_load_tenant_configs_reads_chunked_ssm_and_caches(monkeypatch, aws):
    ssm = boto3.client('ssm', region_name='us-west-2')
    payload = json.dumps([
        {
            'tenant': 'acgw',
            'prefixes': [
                {
                    'aws_region': 'us-west-2',
                    'deployment_prefix': 'acgw-usw2',
                },
            ],
        },
    ])
    midpoint = len(payload) // 2
    ssm.put_parameter(
        Name='/forge/stuck-worker/config/0',
        Value=payload[:midpoint],
        Type='String',
    )
    ssm.put_parameter(
        Name='/forge/stuck-worker/config/1',
        Value=payload[midpoint:],
        Type='String',
    )
    monkeypatch.setenv(
        'TENANT_CONFIG_PARAMETER_PREFIX',
        '/forge/stuck-worker/config',
    )
    monkeypatch.setenv('TENANT_CONFIG_PARAMETER_COUNT', '2')
    mod = _load_worker(monkeypatch)

    assert mod.load_tenant_configs()[0]['tenant'] == 'acgw'

    def _unexpected_client(*_args, **_kwargs):
        raise AssertionError('tenant config was not served from cache')

    monkeypatch.setattr(mod.boto3, 'client', _unexpected_client)
    cached_config = mod.load_tenant_configs()[0]
    assert cached_config['prefixes'][0]['aws_region'] == 'us-west-2'


def test_resolve_tenant_config_rejects_ambiguous_matches(monkeypatch, aws):
    mod = _load_worker(monkeypatch)
    mod.tenant_configs_cache = [
        {
            'tenant': 'acgw',
            'prefixes': [
                {'aws_region': 'us-west-2', 'deployment_prefix': 'one'},
                {'aws_region': 'us-west-2', 'deployment_prefix': 'two'},
            ],
        },
    ]

    with pytest.raises(ValueError, match='Ambiguous tenant'):
        mod.resolve_tenant_config({
            'tenant': 'acgw',
            'aws_region': 'us-west-2',
        })


def test_process_rows_redelivers_each_candidate(monkeypatch, aws):
    mod = _load_worker(monkeypatch)
    calls = []
    monkeypatch.setattr(
        mod,
        'redeliver_delivery',
        lambda jwt, row, api_url, api_version: calls.append(
            (jwt, row['id'], api_url, api_version)
        ),
    )
    payload = {
        'tenant': 'acgw',
        'aws_region': 'us-west-2',
        'workflow_job_id': 4242,
        'runner_labels': ['self-hosted', 'x64'],
    }
    rows = [mod.delivery_row_from_id('123'), mod.delivery_row_from_id('456')]

    result = mod.process_rows(
        'jwt-token',
        payload,
        rows,
        'https://api.github.test',
        '2022-11-28',
    )

    assert result['redelivered'] == 2
    assert result['candidates'] == 2
    assert calls == [
        ('jwt-token', '123', 'https://api.github.test', '2022-11-28'),
        ('jwt-token', '456', 'https://api.github.test', '2022-11-28'),
    ]


def test_redeliver_delivery_raises_on_github_failure(monkeypatch, aws):
    mod = _load_worker(monkeypatch)
    monkeypatch.setattr(
        mod,
        'github_request',
        lambda *_args, **_kwargs: (
            500,
            {},
            b'{"message":"server error"}',
        ),
    )

    with pytest.raises(RuntimeError, match='GitHub redelivery failed'):
        mod.redeliver_delivery(
            'jwt-token',
            mod.delivery_row_from_id('123'),
            'https://api.github.test',
            '2022-11-28',
        )


def test_claim_work_returns_false_when_already_claimed(monkeypatch, aws):
    mod = _load_worker(monkeypatch)

    class _DynamoDB:
        def update_item(self, **_kwargs):
            raise ClientError({
                'Error': {
                    'Code': 'ConditionalCheckFailedException',
                    'Message': 'condition failed',
                },
            }, 'UpdateItem')

    monkeypatch.setattr(mod, 'dynamodb', _DynamoDB())

    assert not mod.claim_work('tenant#region#repo#job')


def test_lambda_handler_completes_pending_stream_record(monkeypatch, aws):
    mod = _load_worker(monkeypatch)
    completed = []
    monkeypatch.setattr(mod, 'claim_work', lambda key: key == 'key-1')
    monkeypatch.setattr(
        mod,
        'process_payload',
        lambda payload: {'workflow_job_id': payload['workflow_job_id']},
    )
    monkeypatch.setattr(
        mod,
        'complete_work',
        lambda key, status, result: completed.append((key, status, result)),
    )

    result = mod.lambda_handler({
        'Records': [
            {
                'eventName': 'INSERT',
                'dynamodb': {
                    'NewImage': {
                        'dedupe_key': {'S': 'key-1'},
                        'status': {'S': 'pending'},
                        'payload': {'S': json.dumps({'workflow_job_id': 4242})},
                    },
                },
            }
        ],
    }, None)

    assert result == {'failures': []}
    assert completed == [
        ('key-1', 'completed', {'workflow_job_id': 4242}),
    ]


def test_lambda_handler_records_failed_pending_work(monkeypatch, aws):
    mod = _load_worker(monkeypatch)
    completed = []
    monkeypatch.setattr(mod, 'claim_work', lambda _key: True)

    def _fail(_payload):
        raise RuntimeError('github unavailable')

    monkeypatch.setattr(mod, 'process_payload', _fail)
    monkeypatch.setattr(
        mod,
        'complete_work',
        lambda key, status, result: completed.append((key, status, result)),
    )

    result = mod.lambda_handler({
        'Records': [
            {
                'eventName': 'MODIFY',
                'dynamodb': {
                    'NewImage': {
                        'dedupe_key': {'S': 'key-2'},
                        'status': {'S': 'pending'},
                        'payload': {'S': json.dumps({'workflow_job_id': 4242})},
                    },
                },
            }
        ],
    }, None)

    assert result == {
        'failures': [{'key': 'key-2', 'error': 'github unavailable'}],
    }
    assert completed == [
        ('key-2', 'failed', {'error': 'github unavailable'}),
    ]
