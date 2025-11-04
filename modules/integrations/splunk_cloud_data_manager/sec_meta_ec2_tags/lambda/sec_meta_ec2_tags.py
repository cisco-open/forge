import json
import logging
import os
import random
import time
import urllib.request
from typing import Any, Dict, List

import boto3

LOG = logging.getLogger()
level_str = os.environ.get('LOG_LEVEL', 'INFO').upper()
LOG.setLevel(getattr(logging, level_str, logging.INFO))

SPLUNK_MAX_BATCH_BYTES = 600_000_000
SPLUNK_MAX_RETRIES = 5
SPLUNK_RETRY_BASE_SLEEP = 1.0


def lambda_handler(event: Dict[str, Any], _context) -> None:
    instance_ids = extract_instance_ids_from_createtags(event)
    if not instance_ids:
        LOG.info(
            'No instance IDs found (non-CreateTags event or none starting with i-)')
        return

    ec2 = boto3.client('ec2')
    paginator = ec2.get_paginator('describe_instances')

    req = build_hec_request()
    batch = []
    batch_size = 0
    total_sent = 0

    for page in paginator.paginate(InstanceIds=instance_ids):
        for reservation in page.get('Reservations', []):
            for instance in reservation.get('Instances', []):
                payload = {
                    'sourcetype': 'aws:metadata',
                    'source': f'{event.get("account", "unknown")}:{event.get("region", "unknown")}:ec2_instances',
                    'event': instance,
                    'fields': {
                        'data_manager_input_id': os.environ['SPLUNK_DATA_MANAGER_INPUT_ID']
                    },
                }
                encoded = json.dumps(payload, default=_json_default)
                size = len(encoded)
                if batch_size + size > SPLUNK_MAX_BATCH_BYTES:
                    send_events(req, batch)
                    total_sent += len(batch)
                    batch = []
                    batch_size = 0
                batch.append(encoded)
                batch_size += size

    if batch:
        send_events(req, batch)
        total_sent += len(batch)

    LOG.info('Completed. Total event objects sent: %s', total_sent)


def _json_default(obj):
    if hasattr(obj, 'isoformat'):
        return obj.isoformat()
    return str(obj)


def build_hec_request() -> urllib.request.Request:
    hec_url = os.environ['SPLUNK_HEC_HOST'].rstrip(
        '/') + '/services/collector/event'
    req = urllib.request.Request(url=hec_url, method='POST')
    req.add_header('Authorization', 'Splunk ' + os.environ['SPLUNK_HEC_TOKEN'])
    req.add_header('Content-Type', 'application/json')
    return req


def send_events(req: urllib.request.Request, events: List[str]) -> None:
    if not events:
        return
    # Join JSON objects without separators is risky; newline is safer for HEC parsing.
    data = ''.join(events)
    retries = 0
    while True:
        try:
            req.data = data.encode('utf-8')
            resp_raw = urllib.request.urlopen(req, timeout=30).read()
            resp = json.loads(resp_raw.decode('utf-8'))
            if resp.get('text') == 'Success':
                LOG.info('Successfully sent %s events (bytes=%s)',
                         len(events), len(data))
                return
            raise RuntimeError(f"Unexpected HEC response: {resp}")
        except Exception as exc:  # noqa: BLE001
            if retries >= SPLUNK_MAX_RETRIES:
                LOG.error('Failed after %s retries: %s',
                          SPLUNK_MAX_RETRIES, exc)
                return
            sleep_for = SPLUNK_RETRY_BASE_SLEEP + random.random()
            LOG.warning('Send failed (%s); retry %s/%s in %.2fs',
                        exc, retries + 1, SPLUNK_MAX_RETRIES, sleep_for)
            time.sleep(sleep_for)
            retries += 1


def extract_instance_ids_from_createtags(event: Dict[str, Any]) -> List[str]:
    detail = event.get('detail') or {}
    if detail.get('eventName') != 'CreateTags':
        return []

    items = (
        detail.get('requestParameters', {})
        .get('resourcesSet', {})
        .get('items', [])
    )
    return [
        itm.get('resourceId')
        for itm in items
        if isinstance(itm, dict) and str(itm.get('resourceId', '')).startswith('i-')
    ]
