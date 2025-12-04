import json
import logging
import os
from typing import Dict, List

import boto3
from botocore.exceptions import ClientError

LOG = logging.getLogger()
level_str = os.environ.get('LOG_LEVEL', 'INFO').upper()
LOG.setLevel(getattr(logging, level_str, logging.INFO))

sqs = boto3.client('sqs')


def parse_sqs_map(raw: str) -> List[Dict[str, str]]:
    """
    Expected SQS_MAP env var (from Terraform map), now using ARNs:

    {
      "runner-a": {
        "main": "arn:aws:sqs:us-east-1:111122223333:queue-a-main",
        "dlq":  "arn:aws:sqs:us-east-1:111122223333:queue-a-dlq"
      },
      "runner-b": {
        "main": "arn:aws:sqs:us-east-1:111122223333:queue-b-main",
        "dlq":  "arn:aws:sqs:us-east-1:111122223333:queue-b-dlq"
      }
    }

    Returns a list of:
      [{"key": "runner-a", "main": "<arn>", "dlq": "<arn>"}, ...]
    """
    if not raw.strip():
        return []

    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError as e:
        raise Exception(f"Invalid SQS_MAP JSON: {e}. Value: {raw}") from e

    if not isinstance(parsed, dict):
        raise Exception(
            f"SQS_MAP must be a JSON object/map, got: {type(parsed)}"
        )

    mappings: List[Dict[str, str]] = []
    for key, value in parsed.items():
        if not isinstance(value, dict):
            raise Exception(
                f"SQS_MAP['{key}'] must be an object with 'main' and 'dlq'"
            )
        if 'main' not in value or 'dlq' not in value:
            raise Exception(
                f"SQS_MAP['{key}'] missing 'main' or 'dlq' keys: {value}"
            )
        mappings.append(
            {
                'key': key,
                'main': str(value['main']),
                'dlq': str(value['dlq']),
            }
        )

    return mappings


def start_dlq_redrive_to_source(sqs_client, dlq_identifier: str) -> Dict[str, str]:
    """
    Start an SQS message move task from the given DLQ to its *source* queue.

    Uses StartMessageMoveTask with only SourceArn so that SQS
    uses the DLQ's redrive policy to determine the destination.
    """
    LOG.info('Starting message move task for DLQ ARN=%s', dlq_identifier)

    try:
        resp = sqs_client.start_message_move_task(
            SourceArn=dlq_identifier
        )
    except ClientError as e:
        LOG.error(
            'Failed to start message move task for DLQ ARN=%s: %s',
            dlq_identifier,
            e,
            exc_info=True,
        )
        return {
            'status': 'error',
            'dlq_identifier': dlq_identifier,
            'error': str(e),
        }

    task_handle = resp.get('TaskHandle')
    LOG.info(
        'Started message move task for DLQ ARN=%s task_handle=%s',
        dlq_identifier,
        task_handle,
    )

    return {
        'status': 'started',
        'dlq_identifier': dlq_identifier,
        'task_handle': task_handle,
    }


def lambda_handler(event, context):
    raw_sqs_map = os.getenv('SQS_MAP', '')
    mappings = parse_sqs_map(raw_sqs_map)

    if not mappings:
        LOG.warning('SQS_MAP is empty; nothing to do.')
        return {'status': 'noop', 'message': 'SQS_MAP is empty', 'results': []}

    LOG.info(
        'Starting DLQ redrive (StartMessageMoveTask) for %d mapping(s)',
        len(mappings),
    )

    results = []
    for entry in mappings:
        key = entry['key']
        dlq_identifier = entry['dlq']
        main_identifier = entry['main']

        LOG.info(
            'Processing SQS mapping key=%s dlq=%s main=%s',
            key,
            dlq_identifier,
            main_identifier,
        )

        redrive_result = start_dlq_redrive_to_source(sqs, dlq_identifier)

        results.append(
            {
                'key': key,
                'dlq': dlq_identifier,
                'main': main_identifier,
                **redrive_result,
            }
        )

    return {'status': 'ok', 'results': results}
