"""Regional Splunk dependency monitor.

The probe deliberately keeps tenant failures independent: one tenant's SSM,
GitHub App, or organization API failure must not prevent the remaining tenants
from being measured.
"""

from __future__ import annotations

import base64
import json
import logging
import os
import re
import time
from typing import Any
from urllib.parse import quote

import boto3
import common
from botocore.config import Config

LOG = logging.getLogger()
LOG.setLevel(
    getattr(logging, os.environ.get('LOG_LEVEL', 'INFO').upper(), logging.INFO)
)

AWS_REGION = os.environ.get('AWS_REGION', '')
GITHUB_API_VERSION = os.environ.get('GITHUB_API_VERSION', '2022-11-28')
GITHUB_TIMEOUT_SECONDS = int(os.environ.get('GITHUB_TIMEOUT_SECONDS', '10'))
TENANT_PARAMETER_ROOT = '/forge/'
TENANT_PARAMETER_SUFFIX = '/github_ghes_org'
SSM_CLIENT_CONFIG = Config(
    connect_timeout=5,
    read_timeout=10,
    retries={'mode': 'standard', 'total_max_attempts': 4},
)

queued_datapoints: list[dict[str, Any]] = []
queued_events: list[dict[str, Any]] = []

SPLUNK_METRIC_NAMES = {
    'Availability': 'forge.dependency.availability',
    'LatencyMs': 'forge.dependency.latency_ms',
    'ProbeExecuted': 'forge.dependency.probe_executed',
    'RateLimited': 'forge.dependency.rate_limited',
    'RateLimitRemainingPct': 'forge.dependency.rate_limit_remaining_pct',
}


class ProbeFailure(RuntimeError):
    """Expected dependency-probe failure with safe diagnostic metadata."""

    def __init__(
        self,
        step: str,
        message: str,
        *,
        status_code: int = 0,
        headers: dict[str, str] | None = None,
    ) -> None:
        super().__init__(message)
        self.step = step
        self.status_code = status_code
        self.headers = headers or {}


def aws_client(service_name: str) -> Any:
    """Create an AWS client pinned to the Lambda deployment region."""
    if not AWS_REGION:
        raise ValueError('AWS_REGION is missing from the Lambda environment')
    client_kwargs: dict[str, Any] = {'region_name': AWS_REGION}
    if service_name == 'ssm':
        client_kwargs['config'] = SSM_CLIENT_CONFIG
    return boto3.client(service_name, **client_kwargs)


def _normalize_parameter_value(value: str) -> str:
    return value.strip().strip("'\"")


def normalize_private_key(raw_key: str) -> Any:
    """Accept Forge's PEM, base64 PEM, or base64 DER SSM representation."""

    key_text = raw_key.replace('\\n', '\n').strip()
    if 'BEGIN' in key_text:
        return key_text

    decoded = base64.b64decode(re.sub(r'\s+', '', key_text), validate=True)
    if b'BEGIN' in decoded:
        return decoded.decode('utf-8').replace('\\n', '\n').strip()

    from cryptography.hazmat.primitives import serialization

    return serialization.load_der_private_key(decoded, password=None)


def create_github_app_jwt(issuer: str, private_key: Any) -> str:
    import jwt

    now = int(time.time())
    token = jwt.encode(
        {'iat': now - 60, 'exp': now + 540, 'iss': issuer},
        private_key,
        algorithm='RS256',
    )
    return token.decode('ascii') if isinstance(token, bytes) else token


def discover_tenants() -> list[dict[str, Any]]:
    """Discover regional Forge tenants from existing GitHub SSM parameters."""
    LOG.info(
        'tenant_discovery_started aws_region=%s parameter_root=%s '
        'parameter_suffix=%s',
        AWS_REGION,
        TENANT_PARAMETER_ROOT,
        TENANT_PARAMETER_SUFFIX,
    )
    ssm = aws_client('ssm')
    paginator = ssm.get_paginator('describe_parameters')
    parameter_names = []
    for page_number, page in enumerate(
        paginator.paginate(
            ParameterFilters=[
                {
                    'Key': 'Name',
                    'Option': 'BeginsWith',
                    'Values': [TENANT_PARAMETER_ROOT],
                }
            ]
        ),
        start=1,
    ):
        described_parameters = page.get('Parameters', [])
        matching_parameter_names = [
            parameter['Name']
            for parameter in described_parameters
            if parameter.get('Name', '').endswith(TENANT_PARAMETER_SUFFIX)
        ]
        parameter_names.extend(matching_parameter_names)
        LOG.info(
            'tenant_discovery_page page=%s described=%s matched=%s',
            page_number,
            len(described_parameters),
            len(matching_parameter_names),
        )
        LOG.debug(
            'tenant_discovery_page_matches page=%s parameter_names=%s',
            page_number,
            matching_parameter_names,
        )

    parameter_names = sorted(set(parameter_names))
    LOG.info(
        'tenant_discovery_candidates count=%s',
        len(parameter_names),
    )
    if not parameter_names:
        LOG.warning(
            'tenant_discovery_no_candidates aws_region=%s expected_pattern=%s*%s',
            AWS_REGION,
            TENANT_PARAMETER_ROOT,
            TENANT_PARAMETER_SUFFIX,
        )
        return []

    values_by_name = {}
    invalid_parameters = []
    for offset in range(0, len(parameter_names), 10):
        requested_names = parameter_names[offset: offset + 10]
        response = ssm.get_parameters(
            Names=requested_names,
            WithDecryption=False,
        )
        returned_parameters = response.get('Parameters', [])
        values_by_name.update(
            {
                parameter['Name']: _normalize_parameter_value(
                    parameter['Value']
                )
                for parameter in returned_parameters
            }
        )
        batch_invalid_parameters = response.get('InvalidParameters', [])
        invalid_parameters.extend(batch_invalid_parameters)
        LOG.info(
            'tenant_discovery_read requested=%s returned=%s invalid=%s',
            len(requested_names),
            len(returned_parameters),
            len(batch_invalid_parameters),
        )
        LOG.debug(
            'tenant_discovery_read_details requested_names=%s '
            'invalid_names=%s',
            requested_names,
            batch_invalid_parameters,
        )

    if invalid_parameters:
        raise ValueError(
            'One or more Forge tenant discovery parameters are unavailable'
        )

    configs = []
    for parameter_name in parameter_names:
        match = re.fullmatch(
            r'/forge/(?P<deployment_prefix>[^/]+)/github_ghes_org',
            parameter_name,
        )
        github_org = values_by_name.get(parameter_name, '')
        if match is None or not github_org:
            raise ValueError('Forge tenant discovery metadata is invalid')

        tag_response = ssm.list_tags_for_resource(
            ResourceType='Parameter',
            ResourceId=parameter_name,
        )
        parameter_tags = {
            tag['Key']: tag['Value']
            for tag in tag_response.get('TagList', [])
        }
        tenant_tag = parameter_tags.get('TenantName')
        tenant = tenant_tag or github_org
        LOG.info(
            'tenant_discovery_resolved parameter_name=%s '
            'deployment_prefix=%s tenant=%s tenant_source=%s tag_keys=%s',
            parameter_name,
            match.group('deployment_prefix'),
            tenant,
            'TenantName' if tenant_tag else 'github_ghes_org',
            sorted(parameter_tags),
        )
        configs.append(
            {
                'tenant': tenant,
                'aws_region': AWS_REGION,
                'deployment_prefix': match.group('deployment_prefix'),
                'github_api_version': GITHUB_API_VERSION,
            }
        )

    LOG.info('tenant_discovery_complete tenants=%s', len(configs))
    return configs


def load_github_app_credentials(
    ssm: Any, deployment_prefix: str
) -> dict[str, Any]:
    parameter_base = f"/forge/{deployment_prefix}"
    parameter_names = {
        'private_key': f"{parameter_base}/github_app_key",
        'client_id': f"{parameter_base}/github_app_client_id",
        'app_id': f"{parameter_base}/github_app_id",
        'installation_id': (
            f"{parameter_base}/github_app_installation_id"
        ),
        'ghes_url': f"{parameter_base}/github_ghes_url",
        'ghes_org': f"{parameter_base}/github_ghes_org",
    }
    response = ssm.get_parameters(
        Names=list(parameter_names.values()),
        WithDecryption=True,
    )
    values_by_name = {
        parameter['Name']: _normalize_parameter_value(parameter['Value'])
        for parameter in response.get('Parameters', [])
    }
    invalid = set(response.get('InvalidParameters', []))
    missing = [
        name
        for name in parameter_names.values()
        if name not in values_by_name or name in invalid
    ]
    if missing:
        raise ProbeFailure(
            'ssm_credentials',
            'One or more GitHub App SSM parameters are unavailable',
        )

    credentials = {
        key: values_by_name[name] for key, name in parameter_names.items()
    }
    issuer = credentials['client_id'] or credentials['app_id']
    if not issuer:
        raise ProbeFailure(
            'ssm_credentials',
            'Neither GitHub App client ID nor app ID is configured',
        )
    if not credentials['installation_id'] or not credentials['ghes_org']:
        raise ProbeFailure(
            'ssm_credentials',
            'GitHub App installation ID or organization is not configured',
        )

    ghes_url = credentials['ghes_url'].rstrip('/')
    github_api_url = (
        'https://api.github.com'
        if ghes_url in ('', 'https://github.com')
        else f"{ghes_url}/api/v3"
    )

    return {
        'issuer': issuer,
        'private_key': normalize_private_key(credentials['private_key']),
        'installation_id': credentials['installation_id'],
        'github_api_url': github_api_url,
        'github_org': credentials['ghes_org'],
    }


def _lower_headers(headers: Any) -> dict[str, str]:
    return {str(key).lower(): str(value) for key, value in headers.items()}


def github_request(
    method: str,
    url: str,
    *,
    token: str,
    api_version: str,
    body: dict[str, Any] | None = None,
) -> tuple[int, dict[str, str], dict[str, Any]]:
    import requests

    headers = {
        'Accept': 'application/vnd.github+json',
        'Authorization': f"Bearer {token}",
        'Content-Type': 'application/json',
        'User-Agent': 'splunk-dependency-monitor',
    }
    if api_version:
        headers['X-GitHub-Api-Version'] = api_version

    response = requests.request(
        method,
        url,
        headers=headers,
        json=body,
        timeout=GITHUB_TIMEOUT_SECONDS,
    )
    try:
        response_body = response.json()
    except ValueError:
        response_body = {}
    return (
        response.status_code,
        _lower_headers(response.headers),
        response_body,
    )


def get_installation_token(
    config: dict[str, Any],
    jwt_token: str,
    installation_id: str,
) -> tuple[str, int, dict[str, str]]:
    url = (
        f"{config['github_api_url'].rstrip('/')}/app/installations/"
        f"{quote(str(installation_id), safe='')}/access_tokens"
    )
    started = time.monotonic()
    status, headers, body = github_request(
        'POST',
        url,
        token=jwt_token,
        api_version=config['github_api_version'],
    )
    latency_ms = int((time.monotonic() - started) * 1000)
    if status != 201 or not body.get('token'):
        raise ProbeFailure(
            'github_authentication',
            'GitHub App installation-token request failed',
            status_code=status,
            headers=headers,
        )
    return str(body['token']), latency_ms, headers


def check_organization_runner_api(
    config: dict[str, Any],
    installation_token: str,
) -> tuple[int, int, dict[str, str]]:
    organization = quote(config['github_org'], safe='')
    url = (
        f"{config['github_api_url'].rstrip('/')}/orgs/{organization}/"
        'actions/runners?per_page=1'
    )
    started = time.monotonic()
    status, headers, body = github_request(
        'GET',
        url,
        token=installation_token,
        api_version=config['github_api_version'],
    )
    latency_ms = int((time.monotonic() - started) * 1000)
    if status != 200 or 'total_count' not in body:
        raise ProbeFailure(
            'github_org_runners_api',
            'GitHub organization runners API probe failed',
            status_code=status,
            headers=headers,
        )
    return status, latency_ms, headers


def _number_header(headers: dict[str, str], name: str, default: int = -1) -> int:
    try:
        return int(headers.get(name, str(default)))
    except (TypeError, ValueError):
        return default


def _rate_limit_metrics(headers: dict[str, str]) -> dict[str, float | int]:
    limit = _number_header(headers, 'x-ratelimit-limit')
    remaining = _number_header(headers, 'x-ratelimit-remaining')
    used = _number_header(headers, 'x-ratelimit-used')
    if limit <= 0 or remaining < 0:
        return {}
    remaining_pct = round((remaining / limit) * 100, 3)
    return {
        'RateLimit': limit,
        'RateLimitRemaining': remaining,
        'RateLimitUsed': used,
        'RateLimitRemainingPct': remaining_pct,
    }


def _is_rate_limited(status_code: int, headers: dict[str, str]) -> int:
    has_retry_after = headers.get('retry-after') is not None
    remaining_exhausted = headers.get('x-ratelimit-remaining') == '0'
    rate_limit_exhausted = has_retry_after or remaining_exhausted
    return int(status_code in (403, 429) and rate_limit_exhausted)


def _github_mode(config: dict[str, Any]) -> str:
    github_api_url = config.get('github_api_url', '').rstrip('/')
    if not github_api_url:
        return 'unknown'
    if github_api_url == 'https://api.github.com':
        return 'saas'
    return 'ghes'


def queue_metrics(
    config: dict[str, Any],
    *,
    provider: str,
    check_name: str,
    metrics: dict[str, float | int],
) -> None:
    """Queue bounded metric time series for one batched Splunk ingest request."""
    dimensions = {
        'TenantName': config['tenant'],
        'AWSRegion': AWS_REGION,
        'Provider': provider,
        'CheckName': check_name,
        'GitHubMode': _github_mode(config),
    }
    timestamp = int(time.time() * 1000)
    for name, value in metrics.items():
        metric_name = SPLUNK_METRIC_NAMES.get(name)
        if metric_name is None:
            continue
        queued_datapoints.append(
            {
                'metric': metric_name,
                'value': value,
                'timestamp': timestamp,
                'dimensions': dimensions,
            }
        )


def _log_result(
    config: dict[str, Any],
    *,
    provider: str,
    check_name: str,
    success: bool,
    status_code: int = 0,
    error_type: str = '',
) -> None:
    event = {
        'forgecicd_log_type': 'dependency-probe',
        'forgecicd_tenant': config['tenant'],
        'aws_region': AWS_REGION,
        'provider': provider,
        'check_name': check_name,
        'success': success,
        'status_code': status_code,
        'error_type': error_type,
        'github_mode': _github_mode(config),
    }
    queued_events.append(
        {
            'source': 'splunk-dependency-monitor',
            'sourcetype': 'forgecicd:dependency-probe:json',
            'index': common.SPLUNK_INDEX,
            'event': event,
        }
    )
    LOG.info(json.dumps(event, separators=(',', ':'), sort_keys=True))


def probe_tenant(config: dict[str, Any], ssm: Any) -> bool:
    queue_metrics(
        config,
        provider='Forge',
        check_name='TenantCycle',
        metrics={'ProbeExecuted': 1},
    )

    try:
        credentials_started = time.monotonic()
        credentials = load_github_app_credentials(
            ssm, config['deployment_prefix']
        )
        resolved_config = {
            **config,
            'github_api_url': credentials['github_api_url'],
            'github_org': credentials['github_org'],
        }
        ssm_latency_ms = int((time.monotonic() - credentials_started) * 1000)
        queue_metrics(
            resolved_config,
            provider='AWS',
            check_name='SSMCredentials',
            metrics={'Availability': 1, 'LatencyMs': ssm_latency_ms},
        )
        _log_result(
            resolved_config,
            provider='AWS',
            check_name='SSMCredentials',
            success=True,
        )
    except Exception as error:  # Keep every tenant independent.
        queue_metrics(
            config,
            provider='AWS',
            check_name='SSMCredentials',
            metrics={'Availability': 0, 'LatencyMs': 0},
        )
        _log_result(
            config,
            provider='AWS',
            check_name='SSMCredentials',
            success=False,
            error_type=type(error).__name__,
        )
        return False

    try:
        jwt_token = create_github_app_jwt(
            credentials['issuer'], credentials['private_key']
        )
        installation_token, auth_latency_ms, auth_headers = (
            get_installation_token(
                resolved_config,
                jwt_token,
                credentials['installation_id'],
            )
        )
        queue_metrics(
            resolved_config,
            provider='GitHub',
            check_name='Authentication',
            metrics={
                'Availability': 1,
                'LatencyMs': auth_latency_ms,
                'StatusCode': 201,
                'RateLimited': 0,
                **_rate_limit_metrics(auth_headers),
            },
        )
        _log_result(
            resolved_config,
            provider='GitHub',
            check_name='Authentication',
            success=True,
            status_code=201,
        )
    except ProbeFailure as error:
        queue_metrics(
            resolved_config,
            provider='GitHub',
            check_name='Authentication',
            metrics={
                'Availability': 0,
                'LatencyMs': 0,
                'StatusCode': error.status_code,
                'RateLimited': _is_rate_limited(
                    error.status_code, error.headers
                ),
                **_rate_limit_metrics(error.headers),
            },
        )
        _log_result(
            resolved_config,
            provider='GitHub',
            check_name='Authentication',
            success=False,
            status_code=error.status_code,
            error_type=type(error).__name__,
        )
        return False
    except Exception as error:
        queue_metrics(
            resolved_config,
            provider='GitHub',
            check_name='Authentication',
            metrics={
                'Availability': 0,
                'LatencyMs': 0,
                'StatusCode': 0,
                'RateLimited': 0,
            },
        )
        _log_result(
            resolved_config,
            provider='GitHub',
            check_name='Authentication',
            success=False,
            error_type=type(error).__name__,
        )
        return False

    try:
        status, latency_ms, headers = check_organization_runner_api(
            resolved_config, installation_token
        )
        queue_metrics(
            resolved_config,
            provider='GitHub',
            check_name='OrgRunnersApi',
            metrics={
                'Availability': 1,
                'LatencyMs': latency_ms,
                'StatusCode': status,
                'RateLimited': 0,
                **_rate_limit_metrics(headers),
            },
        )
        _log_result(
            resolved_config,
            provider='GitHub',
            check_name='OrgRunnersApi',
            success=True,
            status_code=status,
        )
        return True
    except ProbeFailure as error:
        queue_metrics(
            resolved_config,
            provider='GitHub',
            check_name='OrgRunnersApi',
            metrics={
                'Availability': 0,
                'LatencyMs': 0,
                'StatusCode': error.status_code,
                'RateLimited': _is_rate_limited(
                    error.status_code, error.headers
                ),
                **_rate_limit_metrics(error.headers),
            },
        )
        _log_result(
            resolved_config,
            provider='GitHub',
            check_name='OrgRunnersApi',
            success=False,
            status_code=error.status_code,
            error_type=type(error).__name__,
        )
        return False
    except Exception as error:
        queue_metrics(
            resolved_config,
            provider='GitHub',
            check_name='OrgRunnersApi',
            metrics={
                'Availability': 0,
                'LatencyMs': 0,
                'StatusCode': 0,
                'RateLimited': 0,
            },
        )
        _log_result(
            resolved_config,
            provider='GitHub',
            check_name='OrgRunnersApi',
            success=False,
            error_type=type(error).__name__,
        )
        return False


def deliver_queued_telemetry() -> tuple[int, int, int]:
    """Attempt Splunk Cloud and O11y delivery independently."""
    events_sent = 0
    metrics_sent = 0
    delivery_failures = 0

    try:
        events_sent = common.send_to_splunk_batch(queued_events)
    except Exception as error:
        delivery_failures += 1
        context = common.delivery_error_context(error)
        LOG.error(
            'splunk_cloud_delivery_failed error_type=%s cause_type=%s '
            'http_status=%s response_code=%s response_text=%s',
            type(error).__name__,
            context['cause_type'],
            context['http_status'],
            context['response_code'],
            context['response_text'],
        )

    try:
        metrics_sent = common.send_metric_to_o11y_batch(queued_datapoints)
    except Exception as error:
        delivery_failures += 1
        context = common.delivery_error_context(error)
        LOG.error(
            'splunk_o11y_delivery_failed error_type=%s cause_type=%s '
            'http_status=%s response_code=%s response_text=%s',
            type(error).__name__,
            context['cause_type'],
            context['http_status'],
            context['response_code'],
            context['response_text'],
        )

    return events_sent, metrics_sent, delivery_failures


def lambda_handler(_event: dict[str, Any], _context: Any) -> dict[str, int]:
    queued_datapoints.clear()
    queued_events.clear()
    configs = discover_tenants()
    ssm = aws_client('ssm')
    succeeded = 0
    failed = 0

    for config in configs:
        if probe_tenant(config, ssm):
            succeeded += 1
        else:
            failed += 1

    events_sent, metrics_sent, delivery_failures = (
        deliver_queued_telemetry()
    )
    LOG.info(
        'dependency_probe_complete tenants=%s succeeded=%s failed=%s '
        'events_sent=%s metrics_sent=%s delivery_failures=%s',
        len(configs),
        succeeded,
        failed,
        events_sent,
        metrics_sent,
        delivery_failures,
    )
    return {
        'tenants': len(configs),
        'succeeded': succeeded,
        'failed': failed,
        'events_sent': events_sent,
        'metrics_sent': metrics_sent,
        'delivery_failures': delivery_failures,
    }
