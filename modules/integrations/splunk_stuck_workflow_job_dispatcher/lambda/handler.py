import base64
import hashlib
import json
import logging
import os
import re
import secrets
import time
import urllib.parse
from typing import Any, Dict, Iterable, List

import boto3
from botocore.exceptions import ClientError

LOG = logging.getLogger()
LOG.setLevel(getattr(logging, os.environ.get(
    'LOG_LEVEL', 'INFO').upper(), logging.INFO))

dynamodb = boto3.client('dynamodb')


def response(status_code: int, body: Dict[str, Any]) -> Dict[str, Any]:
    return {
        'statusCode': status_code,
        'headers': {'content-type': 'application/json'},
        'body': json.dumps(body, separators=(',', ':')),
    }


def header_value(event: Dict[str, Any], header_name: str) -> str:
    for key, value in (event.get('headers') or {}).items():
        if key.lower() == header_name.lower():
            return str(value)
    return ''


def request_metadata(event: Dict[str, Any]) -> Dict[str, Any]:
    request_context = event.get('requestContext') or {}
    http_context = request_context.get('http') or {}
    token = (event.get('pathParameters') or {}).get('token') or ''

    return {
        'request_id': request_context.get('requestId') or '',
        'route_key': request_context.get('routeKey') or '',
        'method': http_context.get('method') or '',
        'path': http_context.get('path') or '',
        'source_ip': http_context.get('sourceIp') or '',
        'user_agent': header_value(event, 'user-agent'),
        'token_present': bool(token),
        'token_length': len(token),
    }


def parse_body(event: Dict[str, Any]) -> Dict[str, Any]:
    raw_body = event.get('body') or ''
    if event.get('isBase64Encoded'):
        raw_body = base64.b64decode(raw_body).decode('utf-8')

    content_type = ''
    for key, value in (event.get('headers') or {}).items():
        if key.lower() == 'content-type':
            content_type = value.lower()
            break

    if 'application/x-www-form-urlencoded' in content_type:
        parsed = urllib.parse.parse_qs(raw_body)
        payload = parsed.get('payload', [None])[
            0] or parsed.get('body', [None])[0]
        if payload:
            return json.loads(payload)
        return {key: values[-1] if values else '' for key, values in parsed.items()}

    if not raw_body:
        return {}

    return json.loads(raw_body)


def decode_results_value(value: Any) -> List[Dict[str, Any]]:
    if isinstance(value, dict):
        nested = decode_results_value(value.get('results'))
        return nested or [value]
    if isinstance(value, list):
        return [item for item in value if isinstance(item, dict)]
    if isinstance(value, str) and value.strip().startswith(('{', '[')):
        parsed = json.loads(value)
        return decode_results_value(parsed)

    return []


def extract_results(payload: Dict[str, Any]) -> List[Dict[str, Any]]:
    for key in ('result', 'results'):
        results = decode_results_value(payload.get(key))
        if results:
            return results
    return [payload] if payload else []


def first_value(value: Any) -> str:
    if value is None:
        return ''
    if isinstance(value, list):
        for item in value:
            selected = first_value(item)
            if selected:
                return selected
        return ''
    return str(value).strip()


def first_present(result: Dict[str, Any], *keys: str) -> str:
    for key in keys:
        value = first_value(result.get(key))
        if value:
            return value
    return ''


def split_multivalue(value: Any) -> List[str]:
    if value is None:
        return []
    if isinstance(value, list):
        items: List[str] = []
        for item in value:
            items.extend(split_multivalue(item))
        return dedupe_preserving_order(items)
    raw = str(value).strip()
    if not raw:
        return []
    if raw.startswith('['):
        try:
            parsed = json.loads(raw)
            if isinstance(parsed, list):
                return split_multivalue(parsed)
        except json.JSONDecodeError:
            pass
    return dedupe_preserving_order([part for part in re.split(r'[\s,]+', raw) if part])


def dedupe_preserving_order(values: Iterable[str]) -> List[str]:
    seen = set()
    result = []
    for value in values:
        normalized = str(value).strip()
        if normalized and normalized not in seen:
            seen.add(normalized)
            result.append(normalized)
    return result


def parse_region(result: Dict[str, Any]) -> str:
    explicit = first_present(result, 'aws_region', 'region')
    if explicit:
        return explicit

    queued_url = first_value(result.get('queued_url'))
    match = re.search(
        r'https?://sqs[.-]([a-z0-9-]+)\.amazonaws\.com', queued_url)
    if match:
        return match.group(1)

    return ''


def normalize_result(result: Dict[str, Any]) -> Dict[str, Any]:
    workflow_job_id = first_present(
        result,
        'workflowJobId',
        'workflow_job_id',
        'github.workflowJobId',
    )
    repository = first_present(result, 'repository', 'github.repository')
    tenant = first_present(result, 'forgecicd_tenant', 'tenant')
    region = parse_region(result)
    github_delivery = split_multivalue(first_present(
        result,
        'github_delivery',
        'github.github-delivery',
        'github_deliveries',
        'delivery_ids',
        'delivery_id',
    ))

    normalized = {
        'workflow_job_id': workflow_job_id,
        'repository': repository,
        'tenant': tenant,
        'region': region,
        'github_delivery': github_delivery,
        'stuck_minutes': first_value(result.get('stuck_minutes')),
        'stuck_since': first_value(result.get('stuck_since')),
        'queued_url': first_value(result.get('queued_url')),
        'job_name': first_value(result.get('job_name')),
    }

    missing = [
        key
        for key in ('workflow_job_id', 'tenant', 'region')
        if not normalized.get(key)
    ]
    if not github_delivery:
        missing.append('github_delivery')
    if missing:
        raise ValueError(
            f"Splunk result missing required fields: {', '.join(missing)}")

    return normalized


def dedupe_key(payload: Dict[str, Any]) -> str:
    tenant = payload.get('tenant') or 'unknown'
    region = payload.get('region') or 'unknown'
    repository = payload.get('repository') or 'unknown'
    return f"{tenant}#{region}#{repository}#{payload['workflow_job_id']}"


def put_pending_work_once(key: str, payload: Dict[str, Any]) -> bool:
    table = os.environ['DEDUPE_TABLE']
    now = int(time.time())
    ttl = now + int(os.environ.get('DEDUPE_TTL_SECONDS', '1800'))
    payload_json = json.dumps(payload, sort_keys=True, separators=(',', ':'))
    payload_hash = hashlib.sha256(payload_json.encode('utf-8')).hexdigest()

    try:
        dynamodb.put_item(
            TableName=table,
            Item={
                'dedupe_key': {'S': key},
                'created_at': {'N': str(now)},
                'expires_at': {'N': str(ttl)},
                'payload': {'S': payload_json},
                'payload_hash': {'S': payload_hash},
                'status': {'S': 'pending'},
            },
            ConditionExpression='attribute_not_exists(dedupe_key) OR expires_at < :now',
            ExpressionAttributeValues={':now': {'N': str(now)}},
        )
        return True
    except ClientError as err:
        if err.response.get('Error', {}).get('Code') == 'ConditionalCheckFailedException':
            return False
        raise


def validate_request(event: Dict[str, Any]) -> None:
    method = (event.get('requestContext') or {}).get('http', {}).get('method')
    if method and method.upper() != 'POST':
        raise PermissionError('Only POST is allowed')

    expected_token = os.environ['WEBHOOK_TOKEN']
    provided_token = (event.get('pathParameters') or {}).get('token') or ''
    if not secrets.compare_digest(expected_token, provided_token):
        raise PermissionError('Invalid webhook token')


def lambda_handler(event, _context):
    request_meta = request_metadata(event)

    try:
        validate_request(event)
        payload = parse_body(event)
        results = extract_results(payload)
        if not results:
            LOG.info('splunk_webhook_skip reason=no_results')
            return response(200, {'message': 'No results to dispatch'})

        queued = []
        skipped = []
        for result in results:
            work_payload = normalize_result(result)
            key = dedupe_key(work_payload)
            if not put_pending_work_once(key, work_payload):
                LOG.info('splunk_webhook_skip reason=duplicate key=%s', key)
                skipped.append({'key': key, 'reason': 'duplicate'})
                continue

            LOG.info(
                'redelivery_work_queued key=%s repository=%s tenant=%s region=%s github_delivery=%d',
                key,
                work_payload.get('repository'),
                work_payload.get('tenant'),
                work_payload.get('region'),
                len(work_payload.get('github_delivery') or []),
            )
            queued.append(
                {'key': key, 'workflow_job_id': work_payload['workflow_job_id']})

        return response(202, {'queued': queued, 'skipped': skipped})

    except PermissionError as err:
        LOG.warning(
            'request_rejected reason=%s request=%s',
            err,
            json.dumps(request_meta, sort_keys=True),
        )
        return response(403, {'message': str(err)})
    except Exception as err:
        LOG.exception(
            'dispatcher_failed error=%s request=%s',
            err,
            json.dumps(request_meta, sort_keys=True),
        )
        return response(500, {'message': str(err)})
