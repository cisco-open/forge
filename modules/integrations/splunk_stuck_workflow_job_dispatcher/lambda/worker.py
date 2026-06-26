import base64
import hashlib
import json
import logging
import os
import re
import time
import urllib.error
import urllib.request
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
SHA256_DIGESTINFO_PREFIX = bytes.fromhex(
    '3031300d060960864801650304020105000420')


class DerReader:
    def __init__(self, data: bytes):
        self.data = data
        self.pos = 0

    def eof(self) -> bool:
        return self.pos >= len(self.data)

    def peek_tag(self) -> int:
        if self.eof():
            raise ValueError('Unexpected end of DER data')
        return self.data[self.pos]

    def read_tlv(self) -> Tuple[int, bytes]:
        if self.eof():
            raise ValueError('Unexpected end of DER data')

        tag = self.data[self.pos]
        self.pos += 1
        if self.eof():
            raise ValueError('Missing DER length')

        length_octet = self.data[self.pos]
        self.pos += 1
        if length_octet & 0x80:
            length_octets = length_octet & 0x7F
            if length_octets == 0:
                raise ValueError('Indefinite DER length is not supported')
            if self.pos + length_octets > len(self.data):
                raise ValueError('DER length exceeds input')
            length = int.from_bytes(
                self.data[self.pos:self.pos + length_octets], 'big')
            self.pos += length_octets
        else:
            length = length_octet

        if self.pos + length > len(self.data):
            raise ValueError('DER value exceeds input')

        value = self.data[self.pos:self.pos + length]
        self.pos += length
        return tag, value

    def read_sequence(self) -> 'DerReader':
        tag, value = self.read_tlv()
        if tag != 0x30:
            raise ValueError(f"Expected DER SEQUENCE, got tag 0x{tag:02x}")
        return DerReader(value)

    def read_integer(self) -> int:
        tag, value = self.read_tlv()
        if tag != 0x02:
            raise ValueError(f"Expected DER INTEGER, got tag 0x{tag:02x}")
        return int.from_bytes(value.lstrip(b'\x00') or b'\x00', 'big')

    def read_octet_string(self) -> bytes:
        tag, value = self.read_tlv()
        if tag != 0x04:
            raise ValueError(f"Expected DER OCTET STRING, got tag 0x{tag:02x}")
        return value


def json_default(value: Any) -> Any:
    if isinstance(value, Decimal):
        return int(value) if value % 1 == 0 else float(value)
    raise TypeError(f"Unsupported JSON value: {type(value).__name__}")


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b'=').decode('ascii')


def normalize_parameter_value(value: str) -> str:
    return value.strip().strip("'\"")


def pem_to_der(raw_key: str) -> bytes:
    key_text = raw_key.replace('\\n', '\n').strip()
    if 'BEGIN' not in key_text:
        compact = re.sub(r'\s+', '', key_text)
        decoded = base64.b64decode(compact)
        if b'BEGIN' in decoded:
            key_text = decoded.decode('utf-8').replace('\\n', '\n').strip()
        else:
            return decoded

    lines = [
        line.strip()
        for line in key_text.splitlines()
        if line.strip() and not line.startswith('-----')
    ]
    return base64.b64decode(''.join(lines))


def parse_rsa_private_key(raw_key: str) -> Tuple[int, int]:
    der = pem_to_der(raw_key)
    sequence = DerReader(der).read_sequence()
    sequence.read_integer()

    next_tag = sequence.peek_tag()
    if next_tag == 0x30:
        sequence.read_tlv()
        private_key_der = sequence.read_octet_string()
        return parse_rsa_private_key_from_pkcs1(private_key_der)
    if next_tag == 0x02:
        return parse_rsa_private_key_from_sequence(sequence)

    raise ValueError(f"Unsupported private key DER tag 0x{next_tag:02x}")


def parse_rsa_private_key_from_pkcs1(der: bytes) -> Tuple[int, int]:
    sequence = DerReader(der).read_sequence()
    sequence.read_integer()
    return parse_rsa_private_key_from_sequence(sequence)


def parse_rsa_private_key_from_sequence(sequence: DerReader) -> Tuple[int, int]:
    modulus = sequence.read_integer()
    sequence.read_integer()
    private_exponent = sequence.read_integer()
    return modulus, private_exponent


def rsa_sha256_sign(private_key: Tuple[int, int], message: bytes) -> bytes:
    modulus, private_exponent = private_key
    key_size = (modulus.bit_length() + 7) // 8
    digest = hashlib.sha256(message).digest()
    digest_info = SHA256_DIGESTINFO_PREFIX + digest
    padding_length = key_size - len(digest_info) - 3
    if padding_length < 8:
        raise ValueError('RSA key is too small for SHA-256 signature')
    encoded = b'\x00\x01' + (b'\xff' * padding_length) + b'\x00' + digest_info
    signature = pow(int.from_bytes(encoded, 'big'), private_exponent, modulus)
    return signature.to_bytes(key_size, 'big')


def create_github_app_jwt(issuer: str, private_key: Tuple[int, int]) -> str:
    now = int(time.time())
    header = b64url(b'{"typ":"JWT","alg":"RS256"}')
    payload = b64url(
        json.dumps(
            {'iat': now - 60, 'exp': now + 540, 'iss': issuer},
            separators=(',', ':'),
        ).encode('utf-8')
    )
    signing_input = f"{header}.{payload}".encode('ascii')
    signature = b64url(rsa_sha256_sign(private_key, signing_input))
    return f"{header}.{payload}.{signature}"


def github_request(
    jwt: str,
    method: str,
    path: str,
    body: Dict[str, Any] | None = None,
    api_url: str | None = None,
    api_version: str | None = None,
) -> Tuple[int, Dict[str, str], bytes]:
    resolved_api_url = (api_url or 'https://api.github.com').rstrip('/')
    resolved_api_version = (
        '2022-11-28' if api_version is None else api_version
    )
    data = json.dumps(body).encode('utf-8') if body is not None else None
    headers = {
        'Accept': 'application/vnd.github+json',
        'Authorization': f"Bearer {jwt}",
        'Content-Type': 'application/json',
        'User-Agent': 'forge-stuck-workflow-job-redelivery',
    }
    if resolved_api_version:
        headers['X-GitHub-Api-Version'] = resolved_api_version

    request = urllib.request.Request(
        f"{resolved_api_url}{path}",
        data=data,
        headers=headers,
        method=method,
    )

    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            headers = {key.lower(): value for key,
                       value in response.headers.items()}
            return response.status, headers, response.read()
    except urllib.error.HTTPError as err:
        headers = {key.lower(): value for key, value in err.headers.items()}
        return err.code, headers, err.read()


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
        'private_key': parse_rsa_private_key(raw_key),
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

        raise ValueError(f"Invalid delivery ID/GUID: {delivery_reference}")

    return numeric_delivery_ids, delivery_guids


def delivery_row_from_id(delivery_id: str) -> Dict[str, Any]:
    return {
        'id': delivery_id,
        'guid': '-',
        'event': 'explicit-id',
        'action': '-',
        'delivered_at': '-',
        'status_code': '-',
        'status': '-',
        'repository_id': '-',
    }


def delivery_row_from_github_delivery(
    delivery: Dict[str, Any],
) -> Dict[str, Any]:
    delivery_id = str(delivery.get('id') or '').strip()
    if not re.fullmatch(r'\d+', delivery_id):
        raise ValueError(
            f"Resolved GitHub delivery has invalid numeric ID: {delivery_id}")

    return {
        'id': delivery_id,
        'guid': str(delivery.get('guid') or '-'),
        'event': str(delivery.get('event') or '-'),
        'action': str(delivery.get('action') or '-'),
        'delivered_at': str(delivery.get('delivered_at') or '-'),
        'status_code': str(delivery.get('status_code') or '-'),
        'status': str(delivery.get('status') or '-'),
        'repository_id': str(delivery.get('repository_id') or '-'),
    }


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

            rows.append(delivery_row_from_github_delivery(delivery))
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
    numeric_delivery_ids, delivery_guids = normalize_delivery_references(
        payload.get('github_delivery') or [])
    if not numeric_delivery_ids and not delivery_guids:
        raise ValueError('No github_delivery provided by Splunk')

    rows = [
        delivery_row_from_id(delivery_id)
        for delivery_id in numeric_delivery_ids
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


def format_event_action(row: Dict[str, Any]) -> str:
    if row.get('action') in {'', '-'}:
        return str(row.get('event') or '-')
    return f"{row.get('event')}.{row.get('action')}"


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
            '%s tenant=%s delivery_id=%s guid=%s event=%s delivered_at=%s status=%s status_code=%s repository_id=%s',
            'redelivery_execute',
            tenant,
            row.get('id'),
            row.get('guid'),
            format_event_action(row),
            row.get('delivered_at'),
            row.get('status'),
            row.get('status_code'),
            row.get('repository_id'),
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
        UpdateExpression='SET #status = :status, finished_at = :now, result = :result',
        ExpressionAttributeNames={'#status': 'status'},
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
