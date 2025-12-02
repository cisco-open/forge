import json
import logging
import os
import time
from typing import Dict, List

import boto3

LOG = logging.getLogger()
level_str = os.environ.get('LOG_LEVEL', 'INFO').upper()
LOG.setLevel(getattr(logging, level_str, logging.INFO))

sqs = boto3.client('sqs')


def parse_sqs_map(raw: str) -> List[Dict[str, str]]:
    """
    Expected SQS_MAP env var (from Terraform map):
    {
      "runner-a": {"main": "queue-a-main", "dlq": "queue-a-dlq"},
      "runner-b": {"main": "queue-b-main", "dlq": "queue-b-dlq"}
    }

    Returns a list of:
      [{"key": "runner-a", "main": "...", "dlq": "..."}, ...]
    """
    if not raw.strip():
        return []

    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError as e:
        raise Exception(f"Invalid SQS_MAP JSON: {e}. Value: {raw}") from e

    if not isinstance(parsed, dict):
        raise Exception(
            f"SQS_MAP must be a JSON object/map, got: {type(parsed)}")

    mappings: List[Dict[str, str]] = []
    for key, value in parsed.items():
        if not isinstance(value, dict):
            raise Exception(
                f"SQS_MAP['{key}'] must be an object with 'main' and 'dlq'")
        if 'main' not in value or 'dlq' not in value:
            raise Exception(
                f"SQS_MAP['{key}'] missing 'main' or 'dlq' keys: {value}")
        mappings.append(
            {
                'key': key,
                'main': str(value['main']),
                'dlq': str(value['dlq']),
            }
        )

    return mappings


def resolve_queue_url(sqs_client, name_or_url: str) -> str:
    """Return URL if already full URL, else resolve by queue name."""
    if name_or_url.startswith('https://'):
        return name_or_url

    resp = sqs_client.get_queue_url(QueueName=name_or_url)
    return resp['QueueUrl']


def drain_dlq(sqs_client, dlq_url: str, main_url: str) -> int:
    """Drain DLQ → main queue, returns number of moved messages."""
    moved = 0

    while True:
        resp = sqs_client.receive_message(
            QueueUrl=dlq_url,
            MaxNumberOfMessages=10,
            WaitTimeSeconds=0,
            VisibilityTimeout=30,
        )

        messages = resp.get('Messages', [])
        if not messages:
            break

        for msg in messages:
            sqs_client.send_message(
                QueueUrl=main_url,
                MessageBody=msg['Body'],
            )
            sqs_client.delete_message(
                QueueUrl=dlq_url,
                ReceiptHandle=msg['ReceiptHandle'],
            )
            moved += 1

        # small throttle to avoid hammering SQS too hard
        time.sleep(0.1)

    return moved


def lambda_handler(event, context):
    raw_sqs_map = os.getenv('SQS_MAP', '')
    mappings = parse_sqs_map(raw_sqs_map)

    if not mappings:
        LOG.warning('SQS_MAP is empty; nothing to do.')
        return {'status': 'noop', 'message': 'SQS_MAP is empty', 'results': []}

    LOG.info('Starting DLQ drain for %d mapping(s)', len(mappings))

    results = []
    for entry in mappings:
        key = entry['key']
        dlq_name_or_url = entry['dlq']
        main_name_or_url = entry['main']

        LOG.info('Processing SQS mapping key=%s dlq=%s main=%s',
                 key, dlq_name_or_url, main_name_or_url)

        dlq_url = resolve_queue_url(sqs, dlq_name_or_url)
        main_url = resolve_queue_url(sqs, main_name_or_url)

        moved = drain_dlq(sqs, dlq_url, main_url)

        LOG.info(
            'Finished SQS mapping key=%s dlq=%s main=%s moved=%d',
            key,
            dlq_name_or_url,
            main_name_or_url,
            moved,
        )

        results.append(
            {
                'key': key,
                'dlq': dlq_name_or_url,
                'main': main_name_or_url,
                'moved': moved,
            }
        )

    return {'status': 'ok', 'results': results}
