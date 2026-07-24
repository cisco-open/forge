"""Forge regional dependency-monitor Lambda tests."""

from __future__ import annotations

import base64
import gzip
import importlib
import json
import sys
from pathlib import Path
from types import SimpleNamespace

import pytest
from conftest import requires_aws

pytestmark = requires_aws

LAMBDA_DIR = Path(__file__).resolve().parents[2].joinpath(
    'modules',
    'integrations',
    'forge_dependency_monitor',
    'lambda',
)


def _load_handler(monkeypatch):
    source = str(LAMBDA_DIR)
    if source not in sys.path:
        sys.path.insert(0, source)
    monkeypatch.setenv('AWS_REGION_ALIAS', 'usw2')
    monkeypatch.setenv('AWS_REGION', 'us-west-2')
    monkeypatch.setenv('GITHUB_API_VERSION', '2022-11-28')
    monkeypatch.setenv('GITHUB_TIMEOUT_SECONDS', '7')
    monkeypatch.setenv('SPLUNK_HEC_TOKEN', 'splunk-hec-token-sensitive')
    monkeypatch.setenv(
        'SPLUNK_HEC_URL',
        'https://http-inputs.example.splunkcloud.com/services/collector',
    )
    monkeypatch.setenv('SPLUNK_HTTP_TIMEOUT_SECONDS', '8')
    monkeypatch.setenv('SPLUNK_INDEX', 'srea-forge-prod-index')
    monkeypatch.setenv(
        'SPLUNK_METRICS_TOKEN', 'splunk-metrics-token-sensitive'
    )
    monkeypatch.setenv(
        'SPLUNK_METRICS_URL',
        'https://ingest.us1.observability.splunkcloud.com/v2/datapoint',
    )
    sys.modules.pop('common', None)
    sys.modules.pop('handler', None)
    return importlib.import_module('handler')


def _tenant_config():
    return {
        'tenant': 'tenant-a',
        'aws_region': 'us-west-2',
        'deployment_prefix': 'tenant-a-usw2-sl',
        'region_alias': 'usw2',
        'github_api_version': '2022-11-28',
    }


def _fake_pem():
    begin_marker = bytes(
        [
            45, 45, 45, 45, 45, 66, 69, 71, 73, 78, 32,
            80, 82, 73, 86, 65, 84, 69, 32, 75, 69, 89,
            45, 45, 45, 45, 45,
        ]
    ).decode()
    end_marker = bytes(
        [
            45, 45, 45, 45, 45, 69, 78, 68, 32,
            80, 82, 73, 86, 65, 84, 69, 32, 75, 69, 89,
            45, 45, 45, 45, 45,
        ]
    ).decode()
    return '\n'.join(
        [
            begin_marker,
            'test-key-material',
            end_marker,
        ]
    )


def test_normalize_private_key_decodes_base64_pem(monkeypatch, aws):
    handler = _load_handler(monkeypatch)
    pem = _fake_pem()

    assert handler.normalize_private_key(
        base64.b64encode(pem.encode()).decode()
    ) == pem


@pytest.mark.parametrize(
    ('ghes_url', 'expected_api_url'),
    [
        ('https://github.com', 'https://api.github.com'),
        (
            'https://github.example.com/',
            'https://github.example.com/api/v3',
        ),
    ],
)
def test_load_credentials_uses_existing_forge_ssm_contract(
    monkeypatch, aws, ghes_url, expected_api_url
):
    handler = _load_handler(monkeypatch)
    pem = _fake_pem()
    calls = []

    class FakeSsm:
        def get_parameters(self, *, Names, WithDecryption):
            calls.append((Names, WithDecryption))
            return {
                'Parameters': [
                    {'Name': Names[0], 'Value': base64.b64encode(
                        pem.encode()
                    ).decode()},
                    {'Name': Names[1], 'Value': 'Iv1.client'},
                    {'Name': Names[2], 'Value': '123'},
                    {'Name': Names[3], 'Value': '456'},
                    {
                        'Name': Names[4],
                        'Value': ghes_url,
                    },
                    {'Name': Names[5], 'Value': 'tenant-org'},
                ],
                'InvalidParameters': [],
            }

    credentials = handler.load_github_app_credentials(
        FakeSsm(), 'tenant-a-usw2-sl'
    )

    assert credentials['issuer'] == 'Iv1.client'
    assert credentials['installation_id'] == '456'
    assert credentials['github_api_url'] == expected_api_url
    assert credentials['github_org'] == 'tenant-org'
    assert calls == [
        (
            [
                '/forge/tenant-a-usw2-sl/github_app_key',
                '/forge/tenant-a-usw2-sl/github_app_client_id',
                '/forge/tenant-a-usw2-sl/github_app_id',
                '/forge/tenant-a-usw2-sl/github_app_installation_id',
                '/forge/tenant-a-usw2-sl/github_ghes_url',
                '/forge/tenant-a-usw2-sl/github_ghes_org',
            ],
            True,
        )
    ]


def test_org_runner_probe_uses_tenant_api_org_and_rate_headers(
    monkeypatch, aws
):
    handler = _load_handler(monkeypatch)
    calls = []

    def request(method, url, headers, json, timeout):
        calls.append((method, url, headers, json, timeout))
        return SimpleNamespace(
            status_code=200,
            headers={
                'X-RateLimit-Limit': '15000',
                'X-RateLimit-Remaining': '14900',
                'X-RateLimit-Used': '100',
            },
            json=lambda: {'total_count': 1, 'runners': []},
        )

    monkeypatch.setitem(
        sys.modules, 'requests', SimpleNamespace(request=request)
    )

    status, _latency, headers = handler.check_organization_runner_api(
        {
            **_tenant_config(),
            'github_api_url': 'https://api.github.test',
            'github_org': 'tenant-org',
        },
        'installation-token',
    )

    assert status == 200
    assert calls[0][0:2] == (
        'GET',
        'https://api.github.test/orgs/tenant-org/actions/runners?per_page=1',
    )
    assert calls[0][2]['Authorization'] == 'Bearer installation-token'
    assert calls[0][4] == 7
    assert handler._rate_limit_metrics(headers) == {
        'RateLimit': 15000,
        'RateLimitRemaining': 14900,
        'RateLimitUsed': 100,
        'RateLimitRemainingPct': pytest.approx(99.333),
    }


def test_lambda_handler_keeps_tenant_failures_independent(monkeypatch, aws):
    handler = _load_handler(monkeypatch)
    configs = [
        {**_tenant_config(), 'tenant': 'tenant-a'},
        {**_tenant_config(), 'tenant': 'tenant-b'},
    ]
    seen = []
    monkeypatch.setattr(handler, 'discover_tenants', lambda: configs)
    monkeypatch.setattr(
        handler.boto3,
        'client',
        lambda _service, *, region_name: (
            region_name == 'us-west-2' and object()
        ),
    )

    def probe(config, _ssm):
        seen.append(config['tenant'])
        return config['tenant'] == 'tenant-b'

    monkeypatch.setattr(handler, 'probe_tenant', probe)
    monkeypatch.setattr(
        handler.common, 'send_to_splunk_batch', lambda _events: 0
    )
    monkeypatch.setattr(
        handler.common, 'send_metric_to_o11y_batch', lambda _metrics: 0
    )

    result = handler.lambda_handler({}, None)

    assert seen == ['tenant-a', 'tenant-b']
    assert result == {
        'tenants': 2,
        'succeeded': 1,
        'failed': 1,
        'events_sent': 0,
        'metrics_sent': 0,
        'delivery_failures': 0,
    }


def test_splunk_cloud_and_o11y_batches_do_not_expose_credentials(
    monkeypatch, aws, capsys, caplog
):
    handler = _load_handler(monkeypatch)
    config = _tenant_config()
    requests_seen = []
    secret_values = [
        'PRIVATE-KEY-CONTENT',
        'signed-jwt',
        'installation-token',
        'installation-id-sensitive-456',
        'splunk-hec-token-sensitive',
        'splunk-metrics-token-sensitive',
    ]

    def post(url, headers, data=None, json=None, timeout=None):
        requests_seen.append((url, headers, data, json, timeout))
        return SimpleNamespace(status_code=200)

    monkeypatch.setitem(sys.modules, 'requests', SimpleNamespace(post=post))

    handler.queue_metrics(
        config,
        provider='GitHub',
        check_name='OrgRunnersApi',
        metrics={
            'Availability': 1,
            'RateLimitRemainingPct': 75,
            'StatusCode': 200,
        },
    )
    handler._log_result(
        config,
        provider='GitHub',
        check_name='OrgRunnersApi',
        success=True,
        status_code=200,
    )

    events_sent = handler.common.send_to_splunk_batch(handler.queued_events)
    metrics_sent = handler.common.send_metric_to_o11y_batch(
        handler.queued_datapoints
    )

    assert events_sent == 1
    assert metrics_sent == 2
    assert requests_seen[0][0] == (
        'https://http-inputs.example.splunkcloud.com/services/collector'
    )
    assert requests_seen[0][1]['Authorization'] == (
        'Splunk splunk-hec-token-sensitive'
    )
    assert requests_seen[0][1]['Content-Encoding'] == 'gzip'
    assert requests_seen[0][4] == 8
    hec_event = json.loads(gzip.decompress(requests_seen[0][2]))
    assert hec_event['index'] == 'srea-forge-prod-index'
    assert hec_event['event']['forgecicd_tenant'] == 'tenant-a'
    assert hec_event['event']['aws_region'] == 'us-west-2'
    assert requests_seen[1][0] == (
        'https://ingest.us1.observability.splunkcloud.com/v2/datapoint'
    )
    assert requests_seen[1][1]['X-SF-TOKEN'] == (
        'splunk-metrics-token-sensitive'
    )
    assert requests_seen[1][4] == 8
    datapoints = requests_seen[1][3]['gauge']
    assert [datapoint['metric'] for datapoint in datapoints] == [
        'forge.dependency.availability',
        'forge.dependency.rate_limit_remaining_pct',
    ]
    assert datapoints[0]['dimensions']['TenantName'] == 'tenant-a'
    assert datapoints[0]['dimensions']['Provider'] == 'GitHub'
    combined_output = capsys.readouterr().out + caplog.text
    assert all(secret not in combined_output for secret in secret_values)


def test_o11y_ingest_retries_server_failure(monkeypatch, aws):
    handler = _load_handler(monkeypatch)
    statuses = iter([503, 200])
    sleeps = []

    def post(url, headers, data=None, json=None, timeout=None):
        _ = (url, headers, data, json, timeout)
        return SimpleNamespace(status_code=next(statuses))

    monkeypatch.setitem(sys.modules, 'requests', SimpleNamespace(post=post))
    monkeypatch.setattr(handler.common.time, 'sleep', sleeps.append)
    handler.queue_metrics(
        _tenant_config(),
        provider='Forge',
        check_name='TenantCycle',
        metrics={'ProbeExecuted': 1},
    )

    assert handler.common.send_metric_to_o11y_batch(
        handler.queued_datapoints
    ) == 1
    assert sleeps == [1]


def test_tenants_are_discovered_from_regional_ssm(monkeypatch, aws):
    handler = _load_handler(monkeypatch)
    calls = []

    class FakePaginator:
        def paginate(self, *, ParameterFilters):
            calls.append(('describe', ParameterFilters))
            return [
                {
                    'Parameters': [
                        {
                            'Name': (
                                '/forge/tenant-a-usw2-sl/github_ghes_org'
                            )
                        },
                        {
                            'Name': (
                                '/forge/tenant-b-usw2-sl/github_ghes_org'
                            )
                        },
                        {'Name': '/forge/tenant-a-usw2-sl/github_app_id'},
                    ]
                }
            ]

    class FakeSsm:
        def get_paginator(self, operation_name):
            assert operation_name == 'describe_parameters'
            return FakePaginator()

        def get_parameters(self, *, Names, WithDecryption):
            calls.append(('get', Names, WithDecryption))
            return {
                'Parameters': [
                    {'Name': Names[0], 'Value': 'github-org-a'},
                    {'Name': Names[1], 'Value': 'github-org-b'},
                ],
                'InvalidParameters': [],
            }

        def list_tags_for_resource(self, *, ResourceType, ResourceId):
            calls.append(('tags', ResourceType, ResourceId))
            tenant = (
                'tenant-a' if 'tenant-a-' in ResourceId else 'tenant-b'
            )
            return {
                'TagList': [
                    {'Key': 'ForgeCICDTenantName', 'Value': tenant},
                ]
            }

    monkeypatch.setattr(
        handler.boto3,
        'client',
        lambda _service, *, region_name: (
            FakeSsm() if region_name == 'us-west-2' else None
        ),
    )

    assert handler.discover_tenants() == [
        {
            'tenant': 'tenant-a',
            'aws_region': 'us-west-2',
            'deployment_prefix': 'tenant-a-usw2-sl',
            'region_alias': 'usw2',
            'github_api_version': '2022-11-28',
        },
        {
            'tenant': 'tenant-b',
            'aws_region': 'us-west-2',
            'deployment_prefix': 'tenant-b-usw2-sl',
            'region_alias': 'usw2',
            'github_api_version': '2022-11-28',
        },
    ]
    assert calls == [
        (
            'describe',
            [
                {
                    'Key': 'Name',
                    'Option': 'BeginsWith',
                    'Values': ['/forge/'],
                }
            ],
        ),
        (
            'get',
            [
                '/forge/tenant-a-usw2-sl/github_ghes_org',
                '/forge/tenant-b-usw2-sl/github_ghes_org',
            ],
            False,
        ),
        (
            'tags',
            'Parameter',
            '/forge/tenant-a-usw2-sl/github_ghes_org',
        ),
        (
            'tags',
            'Parameter',
            '/forge/tenant-b-usw2-sl/github_ghes_org',
        ),
    ]


def test_tenant_discovery_runs_on_every_invocation(monkeypatch, aws):
    handler = _load_handler(monkeypatch)
    describe_calls = 0

    class FakePaginator:
        def paginate(self, **_kwargs):
            nonlocal describe_calls
            describe_calls += 1
            return [{'Parameters': []}]

    class FakeSsm:
        def get_paginator(self, _operation_name):
            return FakePaginator()

    monkeypatch.setattr(
        handler.boto3,
        'client',
        lambda _service, *, region_name: (
            FakeSsm() if region_name == 'us-west-2' else None
        ),
    )

    assert handler.discover_tenants() == []
    assert handler.discover_tenants() == []
    assert describe_calls == 2


def test_splunk_outputs_are_delivered_independently(monkeypatch, aws):
    handler = _load_handler(monkeypatch)
    metrics_seen = []

    def fail_hec(_events):
        raise RuntimeError('HEC unavailable')

    monkeypatch.setattr(handler.common, 'send_to_splunk_batch', fail_hec)
    monkeypatch.setattr(
        handler.common,
        'send_metric_to_o11y_batch',
        lambda metrics: metrics_seen.extend(metrics) or len(metrics),
    )
    handler.queued_events.append({'event': {'success': True}})
    handler.queued_datapoints.append(
        {'metric': 'forge.dependency.availability'})

    assert handler.deliver_queued_telemetry() == (0, 1, 1)
    assert metrics_seen == [{'metric': 'forge.dependency.availability'}]
