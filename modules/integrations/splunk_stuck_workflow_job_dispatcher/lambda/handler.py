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

QUEUE_NAME_SUFFIX = '-queued-builds'
RUNNER_NAME_SUFFIX = '-action-runner'
# Runner EC2 instances are tagged with the workflow_job URL they are bound to
# (set by the GHR scale-up lambda). An empty/absent tag means the instance is
# free and not yet assigned to a job.
RUNNER_WORKFLOW_JOB_URL_TAG = 'ghr:workflow_job_url'
# An instance is considered free (available to pick up a job) only while it is
# still being provisioned or already up. Anything else (shutting-down, stopped,
# terminated) does not count as capacity.
FREE_RUNNER_STATES = ('pending', 'running')
ec2_clients: Dict[str, Any] = {}


def get_ec2_client(region: str):
    client = ec2_clients.get(region)
    if client is None:
        client = boto3.client('ec2', region_name=region)
        ec2_clients[region] = client
    return client


def parse_queued_url(queued_url: str) -> str:
    # Extract the queue name from an SQS URL.
    # e.g. https://sqs.us-west-2.amazonaws.com/123/acgw-usw2-sl-small-queued-builds
    #   -> "acgw-usw2-sl-small-queued-builds"
    if not queued_url:
        return ''
    parsed = urllib.parse.urlparse(queued_url)
    path_parts = [part for part in parsed.path.split('/') if part]
    return path_parts[-1] if path_parts else ''


def runner_name_from_queue(queue_name: str) -> str:
    # Convert a runner-pool queue name into the EC2 instance Name tag.
    # e.g. "acgw-usw2-sl-small-queued-builds" -> "acgw-usw2-sl-small-action-runner"
    if queue_name.endswith(QUEUE_NAME_SUFFIX):
        base = queue_name[: -len(QUEUE_NAME_SUFFIX)]
    else:
        base = queue_name
    if not base:
        return ''
    return f'{base}{RUNNER_NAME_SUFFIX}'


def find_runner_instances(region: str, runner_name: str) -> List[Dict[str, Any]]:
    # Return every EC2 instance matching the runner Name tag in `region`, in
    # ANY state. Callers filter by state and by ghr:workflow_job_url to decide
    # whether each one is busy, free, or already running the stuck job.
    if not region or not runner_name:
        return []
    client = get_ec2_client(region)
    paginator = client.get_paginator('describe_instances')
    pages = paginator.paginate(
        Filters=[
            {'Name': 'tag:Name', 'Values': [runner_name]},
        ]
    )
    instances: List[Dict[str, Any]] = []
    for page in pages:
        for reservation in page.get('Reservations') or []:
            for instance in reservation.get('Instances') or []:
                tags = {
                    tag.get('Key'): tag.get('Value', '')
                    for tag in instance.get('Tags') or []
                }
                instances.append({
                    'instance_id': instance.get('InstanceId'),
                    'state': (instance.get('State') or {}).get('Name'),
                    'workflow_job_url': tags.get(
                        RUNNER_WORKFLOW_JOB_URL_TAG, ''),
                })
    return instances


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


def normalize_result(result: Dict[str, Any]) -> Dict[str, Any]:
    workflow_job_id = result.get('workflowJobId')
    repository = result.get('repository')
    tenant = result.get('forgecicd_tenant')
    aws_region = result.get('aws_region')
    github_delivery = split_multivalue(result.get('github_delivery'))
    runner_labels = split_multivalue(result.get('runner_labels'))

    normalized = {
        'workflow_job_id': workflow_job_id,
        'repository': repository,
        'tenant': tenant,
        'aws_region': aws_region,
        'github_delivery': github_delivery,
        'stuck_minutes': result.get('stuck_minutes'),
        'stuck_since': result.get('stuck_since'),
        'queued_url': result.get('queued_url'),
        'job_name': result.get('job_name'),
        'workflow_job_url': result.get('workflow_job_url'),
        'run_id': result.get('run_id'),
        'run_attempt': result.get('run_attempt'),
        'run_url': result.get('run_url'),
        'workflow_name': result.get('workflow_name'),
        'runner_labels': runner_labels,
        'head_sha': result.get('head_sha'),
        'head_branch': result.get('head_branch'),
        'created_at': result.get('created_at'),
        'started_at': result.get('started_at'),
    }

    required_fields = {
        'workflowJobId': workflow_job_id,
        'forgecicd_tenant': tenant,
        'aws_region': aws_region,
        'queued_url': normalized['queued_url'],
    }
    missing = [key for key, value in required_fields.items() if not value]
    if not github_delivery:
        missing.append('github_delivery')
    if missing:
        raise ValueError(
            f"Splunk result missing required fields: {', '.join(missing)}")

    return normalized


def dedupe_key(payload: Dict[str, Any]) -> str:
    tenant = payload.get('tenant') or 'unknown'
    aws_region = payload.get('aws_region') or 'unknown'
    repository = payload.get('repository') or 'unknown'
    return f"{tenant}#{aws_region}#{repository}#{payload['workflow_job_id']}"


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

        queued: List[Dict[str, Any]] = []
        skipped: List[Dict[str, Any]] = []

        # Phase 1: normalize every Splunk result and group by SQS queue.
        # All results that target the same queue resolve to the same runner
        # pool, so we only need one EC2 lookup per group.
        prepared: List[Dict[str, Any]] = []
        grouped: Dict[str, Dict[str, Any]] = {}
        for result in results:
            work_payload = normalize_result(result)
            queue_name = parse_queued_url(work_payload['queued_url'])
            runner_name = runner_name_from_queue(queue_name)
            ec2_region = work_payload['aws_region']
            entry = {
                'payload': work_payload,
                'queue_name': queue_name,
                'runner_name': runner_name,
                'ec2_region': ec2_region,
                'workflow_job_url': work_payload.get('workflow_job_url') or '',
                # Set if an EC2 already carries this job's URL tag.
                'executed_instance': None,
                # Set if a free runner is available and we choose to wait it out.
                'free_instance': None,
            }
            prepared.append(entry)
            group = grouped.setdefault(queue_name, {
                'runner_name': runner_name,
                'ec2_region': ec2_region,
                'items': [],
            })
            group['items'].append(entry)

        # Phase 2: for each queue group, classify the stuck jobs:
        #   a) job_executed  -> an EC2 already has the job's workflow_job_url
        #                       tagged, so the redelivery already happened.
        #   b) free_runner   -> there is at least one EC2 with no URL tag in a
        #                       pending/running state. Skip up to that many
        #                       jobs and wait for the next Splunk alert to
        #                       re-evaluate; this avoids spawning extra EC2s.
        #   c) otherwise     -> falls through to DynamoDB dedupe + worker.
        for queue_name, group in grouped.items():
            runner_name = group['runner_name']
            region = group['ec2_region']
            items = group['items']
            try:
                instances = find_runner_instances(region, runner_name)
            except ClientError as ec2_err:
                # Fail open: an EC2 API error must not block redelivery.
                LOG.warning(
                    'runner_lookup_failed queue=%s region=%s runner=%s error=%s',
                    queue_name, region, runner_name, ec2_err,
                )
                instances = []

            # (a) Mark jobs whose workflow_job_url already matches a runner.
            url_to_instance = {
                instance['workflow_job_url']: instance
                for instance in instances
                if instance['workflow_job_url']
            }
            pending_items: List[Dict[str, Any]] = []
            for entry in items:
                match = (
                    url_to_instance.get(entry['workflow_job_url'])
                    if entry['workflow_job_url']
                    else None
                )
                if match:
                    entry['executed_instance'] = match
                else:
                    pending_items.append(entry)

            # (b) Cap the skip count at the number of genuinely free runners.
            # "Free" = up (pending/running) AND not yet assigned a job URL.
            free_instances = [
                instance for instance in instances
                if instance['state'] in FREE_RUNNER_STATES
                if not instance['workflow_job_url']
            ]
            skip_count = min(len(pending_items), len(free_instances))
            LOG.info(
                'runner_group queue=%s runner=%s stuck=%d instances=%d executed=%d free=%d skip=%d',
                queue_name,
                runner_name,
                len(items),
                len(instances),
                len(items) - len(pending_items),
                len(free_instances),
                skip_count,
            )
            for idx in range(skip_count):
                pending_items[idx]['free_instance'] = free_instances[idx]

        # Phase 3: emit per-job decisions in the original Splunk order.
        for entry in prepared:
            work_payload = entry['payload']
            key = dedupe_key(work_payload)
            executed_instance = entry['executed_instance']
            free_instance = entry['free_instance']

            if executed_instance:
                LOG.info(
                    'splunk_webhook_skip reason=job_executed key=%s workflow_job_url=%s instance_id=%s state=%s',
                    key,
                    entry['workflow_job_url'],
                    executed_instance.get('instance_id'),
                    executed_instance.get('state'),
                )
                skipped.append({
                    'key': key,
                    'reason': 'job_executed',
                    'workflow_job_url': entry['workflow_job_url'],
                    'instance_id': executed_instance.get('instance_id'),
                    'state': executed_instance.get('state'),
                })
                continue

            if free_instance:
                LOG.info(
                    'splunk_webhook_skip reason=free_runner key=%s runner=%s instance_id=%s state=%s',
                    key,
                    entry['runner_name'],
                    free_instance.get('instance_id'),
                    free_instance.get('state'),
                )
                skipped.append({
                    'key': key,
                    'reason': 'free_runner',
                    'runner_name': entry['runner_name'],
                    'instance_id': free_instance.get('instance_id'),
                    'state': free_instance.get('state'),
                })
                continue

            if not put_pending_work_once(key, work_payload):
                LOG.info('splunk_webhook_skip reason=duplicate key=%s', key)
                skipped.append({'key': key, 'reason': 'duplicate'})
                continue

            LOG.info(
                'redelivery_work_queued key=%s repository=%s tenant=%s aws_region=%s github_delivery=%d runner_labels=%s',
                key,
                work_payload.get('repository'),
                work_payload.get('tenant'),
                work_payload.get('aws_region'),
                len(work_payload.get('github_delivery') or []),
                ','.join(work_payload.get('runner_labels') or []),
            )
            queued.append(
                {
                    'key': key,
                    'workflow_job_id': work_payload['workflow_job_id'],
                    'runner_labels': work_payload.get('runner_labels') or [],
                })

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
