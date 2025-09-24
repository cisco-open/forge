import hashlib
import hmac
import json
import logging
import os

import boto3

EVENT_BUS = os.environ['EVENT_BUS']
SECRET = os.environ.get('GITHUB_SECRET', '').encode()
eb = boto3.client('events')

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, _):
    logger.info('Received event for processing: %s', event)
    signature = event['headers'].get('X-Hub-Signature-256', '')
    body = event['body']

    if SECRET:
        digest = hmac.new(SECRET, body.encode(), hashlib.sha256).hexdigest()
        if not signature.endswith(digest):
            logger.warning(
                'Signature mismatch: provided %s, expected digest %s', signature, digest)
            return {'statusCode': 401, 'body': 'Invalid signature'}

    try:
        payload = json.loads(body)
    except json.JSONDecodeError as e:
        logger.error('JSON decode error: %s', e)
        return {'statusCode': 400, 'body': 'Invalid JSON'}
    gh_event = event['headers'].get('X-GitHub-Event', 'unknown')
    action = payload.get('action', 'none')

    detail_type = f"github.{gh_event}.{action}"

    try:
        response = eb.put_events(
            Entries=[
                {
                    'Source': 'github.webhook',
                    'DetailType': detail_type,
                    'Detail': json.dumps(payload),
                    'EventBusName': EVENT_BUS
                }
            ]
        )
        logger.info('Event forwarded to EventBridge %s, response: %s',
                    EVENT_BUS, response)
    except Exception as e:
        logger.error('Failed to put event to EventBridge: %s', e)
        return {'statusCode': 500, 'body': 'Failed to forward event'}

    return {'statusCode': 200, 'body': 'Event forwarded'}
