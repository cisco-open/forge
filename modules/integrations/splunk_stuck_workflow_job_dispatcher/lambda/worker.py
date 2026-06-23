import base64
import hashlib
import json
import logging
import os
import re
import time
import urllib.error
import urllib.parse
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

TARGET_EVENT = 'workflow_job'
TARGET_ACTION = 'queued'
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


def env_bool(name: str, default: bool = False) -> bool:
    raw = os.environ.get(name)
    if raw is None:
        return default
    return raw.strip().lower() in {'1', 'true', 'yes', 'y', 'on'}


def env_int(name: str, default: int) -> int:
    raw = os.environ.get(name)
    if not raw:
        return default
    return int(raw)


def env_float(name: str, default: float) -> float:
    raw = os.environ.get(name)
    if not raw:
        return default
    return float(raw)


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
    resolved_api_url = (
        api_url or os.environ.get('GITHUB_API_URL', 'https://api.github.com')
    ).rstrip('/')
    resolved_api_version = (
        os.environ.get('GITHUB_API_VERSION', '2022-11-28')
        if api_version is None
        else api_version
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


def github_api_url_from_ghes_url(ghes_url: Any) -> str:
    normalized_ghes_url = str(ghes_url or '').strip().rstrip('/')
    if not normalized_ghes_url:
        return os.environ.get('GITHUB_API_URL', 'https://api.github.com')
    return f"{normalized_ghes_url}/api/v3"


def resolve_tenant_config(payload: Dict[str, Any]) -> Dict[str, str]:
    tenant = payload['tenant']
    aws_region = payload['region']
    region_alias = payload.get('region_alias') or ''
    vpc_alias = payload.get('vpc_alias') or ''
    tenant_configs = json.loads(os.environ.get('TENANT_CONFIGS', '[]'))
    matches = []

    for tenant_config in tenant_configs:
        if tenant_config.get('tenant') != tenant:
            continue

        for prefix_config in tenant_config.get('prefixes', []):
            if prefix_config.get('aws_region') != aws_region:
                continue
            if region_alias and prefix_config.get('region_alias') and (
                prefix_config.get('region_alias') != region_alias
            ):
                continue
            if vpc_alias and prefix_config.get('vpc_alias') and (
                prefix_config.get('vpc_alias') != vpc_alias
            ):
                continue
            gh_config = tenant_config.get('gh_config') or {}
            ghes_url = gh_config.get('ghes_url') or ''
            github_api_url = github_api_url_from_ghes_url(ghes_url)
            github_api_version = (
                tenant_config['github_api_version']
                if 'github_api_version' in tenant_config
                else os.environ.get('GITHUB_API_VERSION', '2022-11-28')
            )
            matches.append({
                'prefix': prefix_config['prefix'],
                'ghes_url': ghes_url,
                'github_api_url': github_api_url,
                'github_api_version': github_api_version,
            })

    if not matches:
        raise ValueError(
            'No tenant prefix configured for '
            f"tenant={tenant} region={aws_region} "
            f"region_alias={region_alias or '-'} vpc_alias={vpc_alias or '-'}"
        )
    if len(matches) > 1:
        raise ValueError(
            'Ambiguous tenant prefix configuration for '
            f"tenant={tenant} region={aws_region} "
            f"region_alias={region_alias or '-'} vpc_alias={vpc_alias or '-'}"
        )

    return matches[0]


def get_parameter(ssm_client, name: str) -> str:
    response = ssm_client.get_parameter(Name=name, WithDecryption=True)
    return normalize_parameter_value(response['Parameter']['Value'])


def load_github_app_credentials(payload: Dict[str, Any]) -> Dict[str, Any]:
    tenant = payload['tenant']
    region = payload['region']
    tenant_config = resolve_tenant_config(payload)
    prefix = tenant_config['prefix']
    ssm_client = boto3.client('ssm', region_name=region)
    parameter_base = f"/forge/{prefix}"

    raw_key = get_parameter(ssm_client, f"{parameter_base}/github_app_key")
    client_id = get_parameter(
        ssm_client, f"{parameter_base}/github_app_client_id")
    app_id = get_parameter(ssm_client, f"{parameter_base}/github_app_id")
    installation_id = get_parameter(
        ssm_client, f"{parameter_base}/github_app_installation_id")

    issuer = client_id or app_id
    if not issuer:
        raise ValueError(
            f"Neither GitHub App client ID nor app ID exists for {prefix}")

    LOG.info(
        'loaded_github_app_credentials tenant=%s region=%s prefix=%s github_mode=%s github_api_url=%s installation_id=%s',
        tenant,
        region,
        prefix,
        'ghes' if tenant_config['ghes_url'] else 'saas',
        tenant_config['github_api_url'],
        installation_id,
    )
    return {
        'issuer': issuer,
        'installation_id': installation_id,
        'private_key': parse_rsa_private_key(raw_key),
        'github_api_url': tenant_config['github_api_url'],
        'github_api_version': tenant_config['github_api_version'],
    }


def is_failed_delivery(delivery: Dict[str, Any]) -> bool:
    status_code = delivery.get('status_code')
    if isinstance(status_code, int):
        return status_code < 200 or status_code >= 300
    if isinstance(status_code, str) and status_code.isdigit():
        code = int(status_code)
        return code < 200 or code >= 300

    status_text = str(delivery.get('status') or '').lower()
    return bool(status_text and status_text not in {'ok', 'success'})


def delivery_matches(delivery: Dict[str, Any], installation_id: str) -> bool:
    include_successful = env_bool('INCLUDE_SUCCESSFUL')
    event_matches = delivery.get('event') == TARGET_EVENT
    action_matches = delivery.get('action') == TARGET_ACTION
    status_matches = include_successful or is_failed_delivery(delivery)
    installation_matches = (
        str(delivery.get('installation_id') or '') == str(installation_id)
    )
    return all((
        event_matches,
        action_matches,
        status_matches,
        installation_matches,
    ))


def delivery_row(delivery: Dict[str, Any]) -> Dict[str, Any]:
    return {
        'id': str(delivery.get('id') or ''),
        'guid': str(delivery.get('guid') or '-'),
        'event': str(delivery.get('event') or '-'),
        'action': str(delivery.get('action') or '-'),
        'delivered_at': str(delivery.get('delivered_at') or '-'),
        'status_code': str(delivery.get('status_code') or '-'),
        'status': str(delivery.get('status') or '-'),
        'repository_id': str(delivery.get('repository_id') or '-'),
    }


def parse_next_cursor(headers: Dict[str, str]) -> str:
    link = headers.get('link', '')
    for segment in link.split(','):
        if 'rel="next"' not in segment:
            continue
        match = re.search(r'[?&]cursor=([^&>]+)', segment)
        if match:
            return urllib.parse.unquote(match.group(1))
    return ''


def list_delivery_pages(
    jwt: str,
    limit: int,
    api_url: str | None = None,
    api_version: str | None = None,
) -> Iterable[List[Dict[str, Any]]]:
    per_page = env_int('PER_PAGE', 100)
    path = f"/app/hook/deliveries?per_page={per_page}"
    scanned = 0

    while scanned < limit:
        status, headers, body = github_request(
            jwt,
            'GET',
            path,
            api_url=api_url,
            api_version=api_version,
        )
        if status != 200:
            raise RuntimeError(
                f"GitHub delivery list failed HTTP {status}: {body.decode('utf-8', 'replace')}")

        page = json.loads(body.decode('utf-8'))
        if not isinstance(page, list):
            raise RuntimeError(
                'GitHub delivery list response was not an array')

        remaining = limit - scanned
        selected_page = page[:remaining]
        scanned += len(selected_page)
        yield selected_page

        if len(page) == 0 or len(selected_page) < len(page):
            break

        cursor = parse_next_cursor(headers)
        if not cursor:
            break
        path = f"/app/hook/deliveries?per_page={per_page}&cursor={urllib.parse.quote(cursor)}"


def scan_matching_deliveries(
    jwt: str,
    installation_id: str,
    api_url: str | None = None,
    api_version: str | None = None,
) -> List[Dict[str, Any]]:
    max_deliveries = env_int('MAX_DELIVERIES', 5000)
    rows: List[Dict[str, Any]] = []
    scanned = 0

    for page in list_delivery_pages(jwt, max_deliveries, api_url, api_version):
        scanned += len(page)
        rows.extend(delivery_row(delivery)
                    for delivery in page if delivery_matches(delivery, installation_id))

    LOG.info('delivery_scan_complete scanned=%d matches=%d', scanned, len(rows))
    return rows


def normalize_delivery_ids(values: Iterable[Any]) -> Tuple[List[str], List[str]]:
    numeric_ids: List[str] = []
    guids: List[str] = []
    seen = set()

    for value in values:
        delivery_id = str(value).strip()
        if not delivery_id or delivery_id in seen:
            continue
        seen.add(delivery_id)

        if re.fullmatch(r'\d+', delivery_id):
            numeric_ids.append(delivery_id)
        elif re.fullmatch(r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', delivery_id):
            guids.append(delivery_id.lower())
        else:
            raise ValueError(f"Invalid delivery ID or GUID: {delivery_id}")

    return numeric_ids, guids


def resolve_delivery_guids(
    jwt: str,
    installation_id: str,
    guids: List[str],
    api_url: str | None = None,
    api_version: str | None = None,
) -> List[Dict[str, Any]]:
    requested = set(guids)
    rows_by_guid: Dict[str, Dict[str, Any]] = {}
    max_deliveries = env_int('MAX_DELIVERIES', 5000)

    for page in list_delivery_pages(jwt, max_deliveries, api_url, api_version):
        for delivery in page:
            guid = str(delivery.get('guid') or '').lower()
            if guid in requested and str(delivery.get('installation_id') or '') == str(installation_id):
                rows_by_guid[guid] = delivery_row(delivery)
        if len(rows_by_guid) == len(requested):
            break

    unresolved = sorted(requested - set(rows_by_guid))
    if unresolved:
        raise RuntimeError(
            f"Delivery GUID(s) not found for installation {installation_id}: {', '.join(unresolved)}")

    return [rows_by_guid[guid] for guid in guids]


def explicit_delivery_rows(
    jwt: str,
    installation_id: str,
    payload: Dict[str, Any],
    api_url: str | None = None,
    api_version: str | None = None,
) -> List[Dict[str, Any]]:
    numeric_ids, guids = normalize_delivery_ids(
        payload.get('delivery_ids') or [])
    rows = [
        {
            'id': delivery_id,
            'guid': '-',
            'event': 'explicit-id',
            'action': '-',
            'delivered_at': '-',
            'status_code': '-',
            'status': '-',
            'repository_id': '-',
        }
        for delivery_id in numeric_ids
    ]
    if guids:
        rows.extend(resolve_delivery_guids(
            jwt,
            installation_id,
            guids,
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
    execute = env_bool('EXECUTE')
    sleep_seconds = env_float('SLEEP_SECONDS', 0)
    tenant = payload['tenant']
    succeeded = 0

    for index, row in enumerate(rows):
        LOG.info(
            '%s tenant=%s delivery_id=%s guid=%s event=%s delivered_at=%s status=%s status_code=%s repository_id=%s',
            'redelivery_execute' if execute else 'redelivery_dry_run',
            tenant,
            row.get('id'),
            row.get('guid'),
            format_event_action(row),
            row.get('delivered_at'),
            row.get('status'),
            row.get('status_code'),
            row.get('repository_id'),
        )

        if execute:
            if index == 0:
                LOG.info('redelivery_preflight tenant=%s delivery_id=%s',
                         tenant, row.get('id'))
            redeliver_delivery(jwt, row, api_url, api_version)
            if sleep_seconds > 0:
                time.sleep(sleep_seconds)

        succeeded += 1

    return {
        'mode': 'execute' if execute else 'dry-run',
        'candidates': len(rows),
        'redelivered': succeeded if execute else 0,
        'tenant': tenant,
        'region': payload['region'],
        'workflow_job_id': payload['workflow_job_id'],
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
    explicit_delivery_count = len(payload.get('delivery_ids') or [])
    if explicit_delivery_count and not env_bool('EXECUTE'):
        numeric_ids, guids = normalize_delivery_ids(
            payload.get('delivery_ids') or [])
        rows = [
            {
                'id': delivery_id,
                'guid': '-',
                'event': 'explicit-id',
                'action': '-',
                'delivered_at': '-',
                'status_code': '-',
                'status': '-',
                'repository_id': '-',
            }
            for delivery_id in numeric_ids
        ]
        rows.extend(
            {
                'id': '-',
                'guid': guid,
                'event': 'explicit-guid',
                'action': '-',
                'delivered_at': '-',
                'status_code': '-',
                'status': '-',
                'repository_id': '-',
            }
            for guid in guids
        )
        return process_rows('', payload, rows)

    credentials = load_github_app_credentials(payload)
    jwt = create_github_app_jwt(
        credentials['issuer'], credentials['private_key'])
    api_url = credentials['github_api_url']
    api_version = credentials['github_api_version']
    if explicit_delivery_count:
        rows = explicit_delivery_rows(
            jwt,
            credentials['installation_id'],
            payload,
            api_url,
            api_version,
        )
    else:
        rows = scan_matching_deliveries(
            jwt,
            credentials['installation_id'],
            api_url,
            api_version,
        )

    return process_rows(jwt, payload, rows, api_url, api_version)


def stream_image_to_item(image: Dict[str, Any]) -> Dict[str, Any]:
    return {key: deserializer.deserialize(value) for key, value in image.items()}


def lambda_handler(event, _context):
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
