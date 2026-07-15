import base64
import json
import logging
import os
import re
import time
from decimal import Decimal
from typing import Any, Dict, Iterable, List, Tuple

import boto3
from boto3.dynamodb.types import TypeDeserializer
from botocore.exceptions import ClientError

LOG = logging.getLogger()
LOG.setLevel(getattr(logging, os.environ.get(
    'LOG_LEVEL', 'INFO').upper(), logging.INFO))

dynamodb = boto3.client('dynamodb')
deserializer = TypeDeserializer()
tenant_configs_cache: List[Dict[str, Any]] | None = None
DELIVERY_GUID_RE = re.compile(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    re.IGNORECASE,
)
MAX_DELIVERIES = 5000
PER_PAGE = 100


def json_default(value: Any) -> Any:
    if isinstance(value, Decimal):
        return int(value) if value % 1 == 0 else float(value)
    raise TypeError(f"Unsupported JSON value: {type(value).__name__}")


def normalize_parameter_value(value: str) -> str:
    return value.strip().strip("'\"")


def normalize_private_key(raw_key: str) -> Any:
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
    if isinstance(token, bytes):
        token = token.decode('ascii')
    return token


def github_request(
    jwt: str,
    method: str,
    path: str,
    body: Dict[str, Any] | None = None,
    api_url: str | None = None,
    api_version: str | None = None,
) -> Tuple[int, Dict[str, str], bytes]:
    import requests

    resolved_api_url = (api_url or 'https://api.github.com').rstrip('/')
    resolved_api_version = (
        '2022-11-28' if api_version is None else api_version
    )
    headers = {
        'Accept': 'application/vnd.github+json',
        'Authorization': f"Bearer {jwt}",
        'Content-Type': 'application/json',
        'User-Agent': 'forge-stuck-workflow-job-redelivery',
    }
    if resolved_api_version:
        headers['X-GitHub-Api-Version'] = resolved_api_version

    response = requests.request(
        method,
        f"{resolved_api_url}{path}",
        headers=headers,
        json=body,
        timeout=30,
    )
    headers = {key.lower(): value for key, value in response.headers.items()}
    return response.status_code, headers, response.content


def load_tenant_configs() -> List[Dict[str, Any]]:
    global tenant_configs_cache

    if tenant_configs_cache is not None:
        return tenant_configs_cache

    parameter_prefix = os.environ.get('TENANT_CONFIG_PARAMETER_PREFIX')
    parameter_count_raw = os.environ.get('TENANT_CONFIG_PARAMETER_COUNT')
    if not parameter_prefix or not parameter_count_raw:
        raise ValueError('Tenant config SSM parameter settings are missing')

    try:
        parameter_count = int(parameter_count_raw)
    except ValueError as err:
        raise ValueError(
            'Tenant config SSM parameter count must be an integer') from err

    if parameter_count < 1:
        raise ValueError(
            'Tenant config SSM parameter count must be at least 1')

    ssm_client = boto3.client('ssm')
    chunks = []
    for index in range(parameter_count):
        parameter_name = f"{parameter_prefix}/{index}"
        response = ssm_client.get_parameter(
            Name=parameter_name,
            WithDecryption=False,
        )
        chunks.append(response['Parameter']['Value'])

    tenant_configs = json.loads(''.join(chunks))
    if not isinstance(tenant_configs, list):
        raise ValueError('Tenant config SSM payload must be a JSON array')

    tenant_configs_cache = tenant_configs
    LOG.info(
        'loaded_tenant_configs source=ssm prefix=%s chunks=%d tenants=%d',
        parameter_prefix,
        parameter_count,
        len(tenant_configs_cache),
    )
    return tenant_configs_cache


def resolve_tenant_config(payload: Dict[str, Any]) -> Dict[str, str]:
    tenant = payload['tenant']
    aws_region = payload['aws_region']
    tenant_configs = load_tenant_configs()
    matches = []

    for tenant_config in tenant_configs:
        if tenant_config.get('tenant') != tenant:
            continue

        for prefix_config in tenant_config.get('prefixes', []):
            if prefix_config.get('aws_region') != aws_region:
                continue
            github_api_url = tenant_config.get('github_api')
            if not github_api_url:
                github_api_url = 'https://api.github.com'
            github_api_version = tenant_config.get('github_api_version')
            if not github_api_version:
                github_api_version = '2022-11-28'
            matches.append({
                'deployment_prefix': prefix_config['deployment_prefix'],
                'github_api_url': github_api_url,
                'github_api_version': github_api_version,
            })

    if not matches:
        raise ValueError(
            'No tenant deployment prefix configured for '
            f"tenant={tenant} aws_region={aws_region}"
        )
    if len(matches) > 1:
        raise ValueError(
            'Ambiguous tenant deployment prefix configuration for '
            f"tenant={tenant} aws_region={aws_region}"
        )

    return matches[0]


def get_parameter(ssm_client, name: str) -> str:
    response = ssm_client.get_parameter(Name=name, WithDecryption=True)
    return normalize_parameter_value(response['Parameter']['Value'])


def get_optional_parameter(ssm_client, name: str) -> str:
    try:
        return get_parameter(ssm_client, name)
    except ClientError as err:
        if err.response.get('Error', {}).get('Code') == 'ParameterNotFound':
            return ''
        raise


def load_github_app_credentials(payload: Dict[str, Any]) -> Dict[str, Any]:
    tenant = payload['tenant']
    aws_region = payload['aws_region']
    tenant_config = resolve_tenant_config(payload)
    deployment_prefix = tenant_config['deployment_prefix']
    ssm_client = boto3.client('ssm', region_name=aws_region)
    parameter_base = f"/forge/{deployment_prefix}"

    raw_key = get_parameter(ssm_client, f"{parameter_base}/github_app_key")
    client_id = get_parameter(
        ssm_client, f"{parameter_base}/github_app_client_id")
    app_id = get_parameter(ssm_client, f"{parameter_base}/github_app_id")
    installation_id = get_optional_parameter(
        ssm_client, f"{parameter_base}/github_app_installation_id")
    issuer = client_id or app_id
    if not issuer:
        raise ValueError(
            f"Neither GitHub App client ID nor app ID exists for {deployment_prefix}")

    LOG.info(
        'loaded_github_app_credentials tenant=%s aws_region=%s deployment_prefix=%s github_mode=%s github_api_url=%s',
        tenant,
        aws_region,
        deployment_prefix,
        'saas' if tenant_config['github_api_url'].rstrip(
            '/') == 'https://api.github.com' else 'ghes',
        tenant_config['github_api_url'],
    )
    return {
        'issuer': issuer,
        'private_key': normalize_private_key(raw_key),
        'github_api_url': tenant_config['github_api_url'],
        'github_api_version': tenant_config['github_api_version'],
        'installation_id': installation_id,
    }


def normalize_delivery_references(
    values: Iterable[Any],
) -> Tuple[List[str], List[str]]:
    numeric_delivery_ids: List[str] = []
    delivery_guids: List[str] = []
    seen_ids = set()
    seen_guids = set()

    if isinstance(values, str):
        values = [values]

    for value in values:
        delivery_reference = str(value).strip()
        if not delivery_reference:
            continue

        if re.fullmatch(r'\d+', delivery_reference):
            if delivery_reference in seen_ids:
                continue
            seen_ids.add(delivery_reference)
            numeric_delivery_ids.append(delivery_reference)
            continue

        if DELIVERY_GUID_RE.fullmatch(delivery_reference):
            delivery_guid = delivery_reference.lower()
            if delivery_guid in seen_guids:
                continue
            seen_guids.add(delivery_guid)
            delivery_guids.append(delivery_guid)
            continue

        raise ValueError(
            f"Invalid GitHub delivery reference: {delivery_reference}")

    return numeric_delivery_ids, delivery_guids


def delivery_row_from_id(delivery_id: str) -> Dict[str, Any]:
    return {'id': delivery_id}


def next_cursor_from_headers(headers: Dict[str, str]) -> str:
    link = headers.get('link') or ''
    for part in link.split(','):
        if 'rel="next"' not in part:
            continue
        match = re.search(r'[?&]cursor=([^&>]+)', part)
        if match:
            return match.group(1)
    return ''


def resolve_delivery_guid_rows(
    jwt: str,
    delivery_guids: List[str],
    installation_id: str,
    api_url: str | None = None,
    api_version: str | None = None,
) -> List[Dict[str, Any]]:
    remaining_guids = set(delivery_guids)
    rows: List[Dict[str, Any]] = []
    path = f"/app/hook/deliveries?per_page={PER_PAGE}"
    scanned = 0
    pages = 0

    while remaining_guids and scanned < MAX_DELIVERIES:
        status, headers, body = github_request(
            jwt,
            'GET',
            path,
            api_url=api_url,
            api_version=api_version,
        )
        if status != 200:
            error_body = body.decode('utf-8', 'replace')
            raise RuntimeError(
                f"GitHub delivery lookup failed HTTP {status}: {error_body}"
            )

        deliveries = json.loads(body.decode('utf-8'))
        if not isinstance(deliveries, list):
            raise ValueError(
                'GitHub delivery lookup returned a non-list payload')

        pages += 1
        delivery_page = deliveries[:max(MAX_DELIVERIES - scanned, 0)]
        scanned += len(delivery_page)

        for delivery in delivery_page:
            if not isinstance(delivery, dict):
                continue
            delivery_guid = str(delivery.get('guid') or '').lower()
            if delivery_guid not in remaining_guids:
                continue
            delivery_installation_id = str(
                delivery.get('installation_id') or '')
            if installation_id and delivery_installation_id != installation_id:
                continue
            delivery_id = str(delivery.get('id') or '').strip()
            if not re.fullmatch(r'\d+', delivery_id):
                raise ValueError(
                    f"Resolved GitHub delivery has invalid numeric ID: {delivery_id}")

            rows.append(delivery_row_from_id(delivery_id))
            remaining_guids.remove(delivery_guid)

        if not deliveries or len(delivery_page) < len(deliveries):
            break

        next_cursor = next_cursor_from_headers(headers)
        if not next_cursor:
            break
        path = (
            f"/app/hook/deliveries?per_page={PER_PAGE}"
            f"&cursor={next_cursor}"
        )

    LOG.info(
        'resolved_delivery_guids requested=%d resolved=%d scanned=%d pages=%d',
        len(delivery_guids),
        len(delivery_guids) - len(remaining_guids),
        scanned,
        pages,
    )
    if remaining_guids:
        raise ValueError(
            'GitHub delivery GUIDs not found in recent deliveries: '
            f"{', '.join(sorted(remaining_guids))}"
        )

    return rows


def delivery_rows(
    payload: Dict[str, Any],
    jwt: str,
    api_url: str | None = None,
    api_version: str | None = None,
    installation_id: str = '',
) -> List[Dict[str, Any]]:
    delivery_ids, delivery_guids = normalize_delivery_references(
        payload.get('github_delivery') or [])
    if not delivery_ids and not delivery_guids:
        raise ValueError('No github_delivery provided by Splunk')

    rows = [
        delivery_row_from_id(delivery_id)
        for delivery_id in delivery_ids
    ]
    if delivery_guids:
        rows.extend(resolve_delivery_guid_rows(
            jwt,
            delivery_guids,
            installation_id,
            api_url,
            api_version,
        ))

    return rows


def redeliver_delivery(
    jwt: str,
    row: Dict[str, Any],
    api_url: str | None = None,
    api_version: str | None = None,
) -> None:
    delivery_id = row['id']
    status, _headers, body = github_request(
        jwt,
        'POST',
        f"/app/hook/deliveries/{delivery_id}/attempts",
        api_url=api_url,
        api_version=api_version,
    )
    if status != 202:
        raise RuntimeError(
            f"GitHub redelivery failed for delivery {delivery_id} HTTP {status}: {body.decode('utf-8', 'replace')}"
        )


def process_rows(
    jwt: str,
    payload: Dict[str, Any],
    rows: List[Dict[str, Any]],
    api_url: str | None = None,
    api_version: str | None = None,
) -> Dict[str, Any]:
    tenant = payload['tenant']
    runner_labels = payload.get('runner_labels') or []
    succeeded = 0

    for index, row in enumerate(rows):
        LOG.info(
            'redelivery_execute tenant=%s delivery_id=%s',
            tenant,
            row.get('id'),
        )

        if index == 0:
            LOG.info(
                'redelivery_preflight tenant=%s delivery_id=%s workflow_job_id=%s runner_labels=%s',
                tenant,
                row.get('id'),
                payload.get('workflow_job_id'),
                ','.join(runner_labels),
            )
        redeliver_delivery(jwt, row, api_url, api_version)

        succeeded += 1

    return {
        'mode': 'execute',
        'candidates': len(rows),
        'redelivered': succeeded,
        'tenant': tenant,
        'aws_region': payload['aws_region'],
        'workflow_job_id': payload['workflow_job_id'],
        'runner_labels': runner_labels,
    }


def claim_work(key: str) -> bool:
    try:
        dynamodb.update_item(
            TableName=os.environ['DEDUPE_TABLE'],
            Key={'dedupe_key': {'S': key}},
            UpdateExpression='SET #status = :processing, started_at = :now',
            ConditionExpression='#status = :pending',
            ExpressionAttributeNames={'#status': 'status'},
            ExpressionAttributeValues={
                ':pending': {'S': 'pending'},
                ':processing': {'S': 'processing'},
                ':now': {'N': str(int(time.time()))},
            },
        )
        return True
    except ClientError as err:
        if err.response.get('Error', {}).get('Code') == 'ConditionalCheckFailedException':
            return False
        raise


def complete_work(key: str, status: str, result: Dict[str, Any]) -> None:
    dynamodb.update_item(
        TableName=os.environ['DEDUPE_TABLE'],
        Key={'dedupe_key': {'S': key}},
        UpdateExpression='SET #status = :status, finished_at = :now, #result = :result',
        ExpressionAttributeNames={'#status': 'status', '#result': 'result'},
        ExpressionAttributeValues={
            ':status': {'S': status},
            ':now': {'N': str(int(time.time()))},
            ':result': {'S': json.dumps(result, sort_keys=True, default=json_default)},
        },
    )


def process_payload(payload: Dict[str, Any]) -> Dict[str, Any]:
    credentials = load_github_app_credentials(payload)
    jwt = create_github_app_jwt(
        credentials['issuer'], credentials['private_key'])
    api_url = credentials['github_api_url']
    api_version = credentials['github_api_version']
    rows = delivery_rows(
        payload,
        jwt,
        api_url,
        api_version,
        credentials.get('installation_id') or '',
    )

    return process_rows(jwt, payload, rows, api_url, api_version)


def stream_image_to_item(image: Dict[str, Any]) -> Dict[str, Any]:
    return {key: deserializer.deserialize(value) for key, value in image.items()}


def lambda_handler(event, _context):
    global tenant_configs_cache

    tenant_configs_cache = None
    failures = []

    for record in event.get('Records', []):
        if record.get('eventName') not in {'INSERT', 'MODIFY'}:
            continue

        image = record.get('dynamodb', {}).get('NewImage') or {}
        item = stream_image_to_item(image)
        key = str(item.get('dedupe_key') or '')
        status = str(item.get('status') or '')
        if not key or status != 'pending':
            LOG.info('worker_skip key=%s status=%s', key, status)
            continue

        if not claim_work(key):
            LOG.info('worker_skip reason=already_claimed key=%s', key)
            continue

        try:
            payload = json.loads(str(item['payload']))
            result = process_payload(payload)
            complete_work(key, 'completed', result)
            LOG.info('redelivery_work_completed key=%s result=%s',
                     key, json.dumps(result, sort_keys=True))
        except Exception as err:
            LOG.exception('redelivery_work_failed key=%s error=%s', key, err)
            complete_work(key, 'failed', {'error': str(err)})
            failures.append({'key': key, 'error': str(err)})

    return {'failures': failures}
