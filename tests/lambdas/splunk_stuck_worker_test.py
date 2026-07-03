"""Splunk stuck workflow-job worker Lambda tests."""

from __future__ import annotations

import importlib
import json
import sys
from pathlib import Path

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


def test_normalize_delivery_references_dedupes_ids_and_guids(
    monkeypatch, aws
):
    mod = _load_worker(monkeypatch)
    guid = 'F1234567-89AB-4CDE-8123-456789ABCDEF'

    ids, guids = mod.normalize_delivery_references([
        '123',
        ' 123 ',
        guid,
        guid.lower(),
        '',
    ])

    assert ids == ['123']
    assert guids == [guid.lower()]


def test_normalize_delivery_references_rejects_invalid_value(
    monkeypatch, aws
):
    mod = _load_worker(monkeypatch)

    with pytest.raises(ValueError, match='Invalid delivery ID/GUID'):
        mod.normalize_delivery_references(['not-a-delivery-reference'])


def test_delivery_rows_combines_explicit_ids_and_resolved_guids(
    monkeypatch, aws
):
    mod = _load_worker(monkeypatch)
    guid = 'f1234567-89ab-4cde-8123-456789abcdef'
    monkeypatch.setattr(
        mod,
        'resolve_delivery_guid_rows',
        lambda jwt, guids, installation_id, api_url, api_version: [
            {
                'id': '99',
                'guid': guids[0],
                'event': 'workflow_job',
                'action': 'queued',
                'delivered_at': '-',
                'status_code': '500',
                'status': 'failed',
                'repository_id': '42',
            }
        ],
    )

    rows = mod.delivery_rows(
        {'github_delivery': ['123', guid]},
        'jwt-token',
        'https://api.github.test',
        '2022-11-28',
        'installation-1',
    )

    assert [row['id'] for row in rows] == ['123', '99']
    assert rows[0]['event'] == 'explicit-id'
    assert rows[1]['guid'] == guid


def test_next_cursor_from_link_header(monkeypatch, aws):
    mod = _load_worker(monkeypatch)

    assert mod.next_cursor_from_headers({
        'link': (
            '<https://api.github.test/app/hook/deliveries?cursor=abc>; '
            'rel="next"'
        ),
    }) == 'abc'
    assert mod.next_cursor_from_headers({'link': '<x>; rel="last"'}) == ''


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


def test_resolve_delivery_guid_rows_pages_and_filters_installation(
    monkeypatch, aws
):
    mod = _load_worker(monkeypatch)
    first_guid = 'f1234567-89ab-4cde-8123-456789abcdef'
    second_guid = 'e1234567-89ab-4cde-8123-456789abcdef'
    calls = []

    def _github_request(_jwt, method, path, **_kwargs):
        calls.append((method, path))
        if len(calls) == 1:
            return 200, {
                'link': (
                    '<https://api.github.test/app/hook/deliveries?'
                    'cursor=next-page>; rel="next"'
                ),
            }, json.dumps([
                {
                    'id': '11',
                    'guid': first_guid,
                    'installation_id': 'wrong-installation',
                },
                {
                    'id': '12',
                    'guid': first_guid,
                    'installation_id': 'install-1',
                    'event': 'workflow_job',
                    'action': 'queued',
                    'delivered_at': '2026-07-03T00:00:00Z',
                    'status_code': 500,
                    'status': 'failed',
                    'repository_id': 42,
                },
            ]).encode()
        return 200, {}, json.dumps([
            {
                'id': '13',
                'guid': second_guid,
                'installation_id': 'install-1',
                'event': 'workflow_job',
                'action': 'in_progress',
                'delivered_at': '2026-07-03T00:01:00Z',
                'status_code': 500,
                'status': 'failed',
                'repository_id': 42,
            },
        ]).encode()

    monkeypatch.setattr(mod, 'github_request', _github_request)

    rows = mod.resolve_delivery_guid_rows(
        'jwt-token',
        [first_guid, second_guid],
        'install-1',
        'https://api.github.test',
        '2022-11-28',
    )

    assert [row['id'] for row in rows] == ['12', '13']
    assert calls == [
        ('GET', '/app/hook/deliveries?per_page=100'),
        ('GET', '/app/hook/deliveries?per_page=100&cursor=next-page'),
    ]


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
