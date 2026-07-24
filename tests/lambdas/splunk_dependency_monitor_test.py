"""Splunk regional dependency-monitor Lambda tests."""

from __future__ import annotations

import base64
import gzip
import importlib.util
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
    'splunk_dependency_monitor',
    'lambda',
)


def _load_handler(monkeypatch):
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
    common_spec = importlib.util.spec_from_file_location(
        'splunk_dependency_monitor_common_under_test',
        LAMBDA_DIR / 'common.py',
    )
    if common_spec is None or common_spec.loader is None:
        raise ImportError('Cannot load dependency-monitor common module')
    common_module = importlib.util.module_from_spec(common_spec)
    common_spec.loader.exec_module(common_module)

    handler_spec = importlib.util.spec_from_file_location(
        'splunk_dependency_monitor_handler_under_test',
        LAMBDA_DIR / 'handler.py',
    )
    if handler_spec is None or handler_spec.loader is None:
        raise ImportError('Cannot load dependency-monitor handler module')
    handler_module = importlib.util.module_from_spec(handler_spec)
    missing = object()
    previous_common = sys.modules.get('common', missing)
    sys.modules['common'] = common_module
    try:
        handler_spec.loader.exec_module(handler_module)
    finally:
        if previous_common is missing:
            sys.modules.pop('common', None)
        else:
            sys.modules['common'] = previous_common
    return handler_module


def _tenant_config():
    return {
        'tenant': 'tenant-a',
        'aws_region': 'us-west-2',
        'deployment_prefix': 'tenant-a-usw2-sl',
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
    assert datapoints[0]['dimensions']['AWSRegion'] == 'us-west-2'
    assert 'RegionAlias' not in datapoints[0]['dimensions']
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
            if 'tenant-a-' in ResourceId:
                return {
                    'TagList': [
                        {'Key': 'TenantName', 'Value': 'tenant-a'},
                    ]
                }
            return {'TagList': []}

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
            'github_api_version': '2022-11-28',
        },
        {
            'tenant': 'github-org-b',
            'aws_region': 'us-west-2',
            'deployment_prefix': 'tenant-b-usw2-sl',
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


def test_tenant_discovery_runs_on_every_invocation(
    monkeypatch, caplog, aws
):
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
    assert caplog.messages.count(
        'tenant_discovery_no_candidates aws_region=us-west-2 '
        'expected_pattern=/forge/*/github_ghes_org'
    ) == 2


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


def test_create_github_app_jwt_uses_bounded_lifetime(monkeypatch, aws):
    handler = _load_handler(monkeypatch)
    captured = {}

    def encode(claims, private_key, *, algorithm):
        captured.update({
            'claims': claims,
            'private_key': private_key,
            'algorithm': algorithm,
        })
        return b'signed-test-token'

    monkeypatch.setattr(handler.time, 'time', lambda: 1000)
    monkeypatch.setitem(sys.modules, 'jwt', SimpleNamespace(encode=encode))

    assert handler.create_github_app_jwt(
        'Iv1.client', 'decoded-key'
    ) == 'signed-test-token'
    assert captured == {
        'claims': {'iat': 940, 'exp': 1540, 'iss': 'Iv1.client'},
        'private_key': 'decoded-key',
        'algorithm': 'RS256',
    }


def test_github_request_normalizes_headers_and_non_json_body(
    monkeypatch, aws
):
    handler = _load_handler(monkeypatch)
    calls = []

    def request(method, url, **kwargs):
        calls.append((method, url, kwargs))

        def invalid_json():
            raise ValueError('not json')

        return SimpleNamespace(
            status_code=502,
            headers={'Retry-After': 30, 'X-RateLimit-Remaining': 0},
            json=invalid_json,
        )

    monkeypatch.setitem(
        sys.modules, 'requests', SimpleNamespace(request=request)
    )

    assert handler.github_request(
        'GET',
        'https://github.example/api',
        token='request-token',
        api_version='',
    ) == (
        502,
        {'retry-after': '30', 'x-ratelimit-remaining': '0'},
        {},
    )
    request_headers = calls[0][2]['headers']
    assert request_headers['Authorization'] == 'Bearer request-token'
    assert 'X-GitHub-Api-Version' not in request_headers
    assert calls[0][2]['timeout'] == 7


def test_installation_token_request_quotes_id_and_measures_latency(
    monkeypatch, aws
):
    handler = _load_handler(monkeypatch)
    calls = []
    monotonic = iter([10.0, 10.125])
    monkeypatch.setattr(handler.time, 'monotonic', lambda: next(monotonic))

    def github_request(method, url, **kwargs):
        calls.append((method, url, kwargs))
        return 201, {'x-ratelimit-remaining': '4999'}, {
            'token': 'installation-token'
        }

    monkeypatch.setattr(handler, 'github_request', github_request)

    result = handler.get_installation_token(
        {
            **_tenant_config(),
            'github_api_url': 'https://github.example/api/v3/',
        },
        'app-jwt',
        'install/id',
    )

    assert result == (
        'installation-token',
        125,
        {'x-ratelimit-remaining': '4999'},
    )
    assert calls == [
        (
            'POST',
            'https://github.example/api/v3/app/installations/'
            'install%2Fid/access_tokens',
            {
                'token': 'app-jwt',
                'api_version': '2022-11-28',
            },
        )
    ]


@pytest.mark.parametrize(
    ('status', 'body'),
    [
        (401, {'message': 'bad credentials'}),
        (201, {}),
    ],
)
def test_installation_token_failure_has_safe_diagnostics(
    monkeypatch, aws, status, body
):
    handler = _load_handler(monkeypatch)
    monkeypatch.setattr(
        handler,
        'github_request',
        lambda *_args, **_kwargs: (
            status,
            {'retry-after': '5'},
            body,
        ),
    )

    with pytest.raises(handler.ProbeFailure) as raised:
        handler.get_installation_token(
            {
                **_tenant_config(),
                'github_api_url': 'https://api.github.com',
            },
            'app-jwt',
            '123',
        )

    assert raised.value.step == 'github_authentication'
    assert raised.value.status_code == status
    assert raised.value.headers == {'retry-after': '5'}
    assert 'app-jwt' not in str(raised.value)


def test_load_credentials_rejects_missing_parameter(monkeypatch, aws):
    handler = _load_handler(monkeypatch)

    class FakeSsm:
        def get_parameters(self, *, Names, WithDecryption):
            assert WithDecryption is True
            return {
                'Parameters': [],
                'InvalidParameters': [Names[0]],
            }

    with pytest.raises(handler.ProbeFailure) as raised:
        handler.load_github_app_credentials(
            FakeSsm(), 'tenant-a-usw2-sl'
        )

    assert raised.value.step == 'ssm_credentials'
    assert raised.value.status_code == 0
    assert '/forge/' not in str(raised.value)


def test_probe_tenant_success_records_each_boundary(monkeypatch, aws):
    handler = _load_handler(monkeypatch)
    monkeypatch.setattr(
        handler,
        'load_github_app_credentials',
        lambda _ssm, _prefix: {
            'issuer': 'Iv1.client',
            'private_key': 'decoded-key',
            'installation_id': '123',
            'github_api_url': 'https://api.github.com',
            'github_org': 'tenant-org',
        },
    )
    monkeypatch.setattr(
        handler,
        'create_github_app_jwt',
        lambda issuer, key: f'{issuer}:{key}',
    )
    monkeypatch.setattr(
        handler,
        'get_installation_token',
        lambda config, token, installation_id: (
            'installation-token',
            12,
            {
                'x-ratelimit-limit': '5000',
                'x-ratelimit-remaining': '4500',
                'x-ratelimit-used': '500',
            },
        ),
    )
    monkeypatch.setattr(
        handler,
        'check_organization_runner_api',
        lambda config, token: (
            200,
            21,
            {
                'x-ratelimit-limit': '5000',
                'x-ratelimit-remaining': '4400',
                'x-ratelimit-used': '600',
            },
        ),
    )

    assert handler.probe_tenant(_tenant_config(), object()) is True
    assert [
        event['event']['check_name'] for event in handler.queued_events
    ] == ['SSMCredentials', 'Authentication', 'OrgRunnersApi']
    assert all(
        event['event']['success'] for event in handler.queued_events
    )
    datapoints = {
        (
            datapoint['dimensions']['CheckName'],
            datapoint['metric'],
        ): datapoint['value']
        for datapoint in handler.queued_datapoints
    }
    assert datapoints[(
        'TenantCycle',
        'forge.dependency.probe_executed',
    )] == 1
    assert datapoints[(
        'SSMCredentials',
        'forge.dependency.availability',
    )] == 1
    assert datapoints[(
        'Authentication',
        'forge.dependency.rate_limit_remaining_pct',
    )] == 90
    assert datapoints[(
        'OrgRunnersApi',
        'forge.dependency.rate_limit_remaining_pct',
    )] == 88


def test_probe_tenant_stops_after_ssm_failure(monkeypatch, aws):
    handler = _load_handler(monkeypatch)
    github_called = False

    def fail_credentials(_ssm, _prefix):
        raise RuntimeError('parameter read failed')

    def create_jwt(*_args):
        nonlocal github_called
        github_called = True

    monkeypatch.setattr(
        handler, 'load_github_app_credentials', fail_credentials
    )
    monkeypatch.setattr(handler, 'create_github_app_jwt', create_jwt)

    assert handler.probe_tenant(_tenant_config(), object()) is False
    assert github_called is False
    assert handler.queued_events[-1]['event'] == {
        'forgecicd_log_type': 'dependency-probe',
        'forgecicd_tenant': 'tenant-a',
        'aws_region': 'us-west-2',
        'provider': 'AWS',
        'check_name': 'SSMCredentials',
        'success': False,
        'status_code': 0,
        'error_type': 'RuntimeError',
        'github_mode': 'unknown',
    }


def test_probe_tenant_reports_rate_limited_authentication(
    monkeypatch, aws
):
    handler = _load_handler(monkeypatch)
    monkeypatch.setattr(
        handler,
        'load_github_app_credentials',
        lambda _ssm, _prefix: {
            'issuer': '123',
            'private_key': 'decoded-key',
            'installation_id': '456',
            'github_api_url': 'https://api.github.com',
            'github_org': 'tenant-org',
        },
    )
    monkeypatch.setattr(
        handler, 'create_github_app_jwt', lambda *_args: 'app-jwt'
    )

    def fail_auth(*_args):
        raise handler.ProbeFailure(
            'github_authentication',
            'installation request failed',
            status_code=429,
            headers={
                'retry-after': '60',
                'x-ratelimit-limit': '5000',
                'x-ratelimit-remaining': '0',
                'x-ratelimit-used': '5000',
            },
        )

    monkeypatch.setattr(handler, 'get_installation_token', fail_auth)

    assert handler.probe_tenant(_tenant_config(), object()) is False
    auth_points = {
        point['metric']: point['value']
        for point in handler.queued_datapoints
        if point['dimensions']['CheckName'] == 'Authentication'
    }
    assert auth_points['forge.dependency.availability'] == 0
    assert auth_points['forge.dependency.rate_limited'] == 1
    assert auth_points['forge.dependency.rate_limit_remaining_pct'] == 0
    assert handler.queued_events[-1]['event']['status_code'] == 429
    assert handler.queued_events[-1]['event']['error_type'] == 'ProbeFailure'


def test_probe_tenant_reports_org_api_failure(monkeypatch, aws):
    handler = _load_handler(monkeypatch)
    monkeypatch.setattr(
        handler,
        'load_github_app_credentials',
        lambda _ssm, _prefix: {
            'issuer': '123',
            'private_key': 'decoded-key',
            'installation_id': '456',
            'github_api_url': 'https://github.example/api/v3',
            'github_org': 'tenant-org',
        },
    )
    monkeypatch.setattr(
        handler, 'create_github_app_jwt', lambda *_args: 'app-jwt'
    )
    monkeypatch.setattr(
        handler,
        'get_installation_token',
        lambda *_args: ('installation-token', 1, {}),
    )

    def fail_org(*_args):
        raise handler.ProbeFailure(
            'github_org_runners_api',
            'organization API failed',
            status_code=403,
            headers={'x-ratelimit-remaining': '0'},
        )

    monkeypatch.setattr(handler, 'check_organization_runner_api', fail_org)

    assert handler.probe_tenant(_tenant_config(), object()) is False
    org_points = {
        point['metric']: point['value']
        for point in handler.queued_datapoints
        if point['dimensions']['CheckName'] == 'OrgRunnersApi'
    }
    assert org_points['forge.dependency.availability'] == 0
    assert org_points['forge.dependency.rate_limited'] == 1
    assert handler.queued_events[-1]['event']['github_mode'] == 'ghes'


def test_lambda_handler_clears_warm_invocation_state(monkeypatch, aws):
    handler = _load_handler(monkeypatch)
    handler.queued_events.append({'stale': True})
    handler.queued_datapoints.append({'stale': True})
    delivered = []

    monkeypatch.setattr(handler, 'discover_tenants', lambda: [])
    monkeypatch.setattr(
        handler.boto3,
        'client',
        lambda _service, *, region_name: object(),
    )
    monkeypatch.setattr(
        handler.common,
        'send_to_splunk_batch',
        lambda events: delivered.append(('events', list(events))) or 0,
    )
    monkeypatch.setattr(
        handler.common,
        'send_metric_to_o11y_batch',
        lambda metrics: delivered.append(('metrics', list(metrics))) or 0,
    )

    assert handler.lambda_handler({}, None) == {
        'tenants': 0,
        'succeeded': 0,
        'failed': 0,
        'events_sent': 0,
        'metrics_sent': 0,
        'delivery_failures': 0,
    }
    assert delivered == [('events', []), ('metrics', [])]


def test_aws_client_requires_explicit_region(monkeypatch, aws):
    handler = _load_handler(monkeypatch)
    monkeypatch.setattr(handler, 'AWS_REGION', '')

    with pytest.raises(ValueError, match='AWS_REGION'):
        handler.aws_client('ssm')


def test_discovery_rejects_unavailable_parameter(monkeypatch, aws):
    handler = _load_handler(monkeypatch)
    parameter_name = '/forge/tenant-a-usw2-sl/github_ghes_org'

    class FakePaginator:
        def paginate(self, **_kwargs):
            return [{'Parameters': [{'Name': parameter_name}]}]

    class FakeSsm:
        def get_paginator(self, _operation_name):
            return FakePaginator()

        def get_parameters(self, **_kwargs):
            return {
                'Parameters': [],
                'InvalidParameters': [parameter_name],
            }

    monkeypatch.setattr(
        handler.boto3,
        'client',
        lambda _service, *, region_name: FakeSsm(),
    )

    with pytest.raises(ValueError, match='unavailable'):
        handler.discover_tenants()


def test_org_runner_probe_rejects_success_without_expected_shape(
    monkeypatch, aws
):
    handler = _load_handler(monkeypatch)
    monkeypatch.setattr(
        handler,
        'github_request',
        lambda *_args, **_kwargs: (200, {}, {'runners': []}),
    )

    with pytest.raises(handler.ProbeFailure) as raised:
        handler.check_organization_runner_api(
            {
                **_tenant_config(),
                'github_api_url': 'https://api.github.com',
                'github_org': 'tenant-org',
            },
            'installation-token',
        )

    assert raised.value.step == 'github_org_runners_api'
    assert raised.value.status_code == 200


@pytest.mark.parametrize('failure_stage', ['authentication', 'organization'])
def test_probe_tenant_handles_unexpected_github_error(
    monkeypatch, aws, failure_stage
):
    handler = _load_handler(monkeypatch)
    monkeypatch.setattr(
        handler,
        'load_github_app_credentials',
        lambda _ssm, _prefix: {
            'issuer': '123',
            'private_key': 'decoded-key',
            'installation_id': '456',
            'github_api_url': 'https://api.github.com',
            'github_org': 'tenant-org',
        },
    )
    monkeypatch.setattr(
        handler, 'create_github_app_jwt', lambda *_args: 'app-jwt'
    )
    if failure_stage == 'authentication':
        monkeypatch.setattr(
            handler,
            'get_installation_token',
            lambda *_args: (_ for _ in ()).throw(
                RuntimeError('JWT signing failure')
            ),
        )
        expected_check = 'Authentication'
    else:
        monkeypatch.setattr(
            handler,
            'get_installation_token',
            lambda *_args: ('installation-token', 1, {}),
        )
        monkeypatch.setattr(
            handler,
            'check_organization_runner_api',
            lambda *_args: (_ for _ in ()).throw(
                RuntimeError('unexpected response failure')
            ),
        )
        expected_check = 'OrgRunnersApi'

    assert handler.probe_tenant(_tenant_config(), object()) is False
    failure_event = handler.queued_events[-1]['event']
    assert failure_event['check_name'] == expected_check
    assert failure_event['status_code'] == 0
    assert failure_event['error_type'] == 'RuntimeError'
    failure_metrics = {
        point['metric']: point['value']
        for point in handler.queued_datapoints
        if point['dimensions']['CheckName'] == expected_check
    }
    assert failure_metrics['forge.dependency.availability'] == 0
    assert failure_metrics['forge.dependency.rate_limited'] == 0


def test_delivery_counts_both_destination_failures(
    monkeypatch, aws, caplog
):
    handler = _load_handler(monkeypatch)

    def fail_delivery(_batch):
        http_error = RuntimeError('request rejected')
        http_error.http_status = 403
        http_error.response_code = '4'
        http_error.response_text = 'Invalid token'
        delivery_error = RuntimeError('destination unavailable')
        delivery_error.__cause__ = http_error
        raise delivery_error

    monkeypatch.setattr(
        handler.common, 'send_to_splunk_batch', fail_delivery
    )
    monkeypatch.setattr(
        handler.common, 'send_metric_to_o11y_batch', fail_delivery
    )

    assert handler.deliver_queued_telemetry() == (0, 0, 2)
    assert caplog.messages == [
        'splunk_cloud_delivery_failed error_type=RuntimeError '
        'cause_type=RuntimeError http_status=403 response_code=4 '
        'response_text=Invalid token',
        'splunk_o11y_delivery_failed error_type=RuntimeError '
        'cause_type=RuntimeError http_status=403 response_code=4 '
        'response_text=Invalid token',
    ]
