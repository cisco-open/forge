import hashlib
import hmac
import json
import logging
import os

import boto3

EVENT_BUS = os.environ['EVENT_BUS']
SECRET = os.environ.get('GITHUB_SECRET', '').encode()
eb = boto3.client('events')

LOG = logging.getLogger()
level_str = os.environ.get('LOG_LEVEL', 'INFO').upper()
LOG.setLevel(getattr(logging, level_str, logging.INFO))


def lambda_handler(event, _):
    try:
        LOG.info('Received event for processing: %s', event)
        signature = event['headers'].get('X-Hub-Signature-256', '')
        body = event['body']

        if SECRET:
            digest = hmac.new(SECRET, body.encode(),
                              hashlib.sha256).hexdigest()
            if not signature.endswith(digest):
                LOG.warning(
                    'Signature mismatch: provided %s, expected digest %s', signature, digest)
                raise ValueError('Invalid signature')

        payload = json.loads(body)
        gh_event = event['headers'].get('X-GitHub-Event', 'unknown')
        action = payload.get('action', 'none')

        detail_type = f"github.{gh_event}.{action}"

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
        LOG.info('Event forwarded to EventBridge %s, response: %s',
                 EVENT_BUS, response)

        return {'statusCode': 200, 'body': 'Event forwarded'}
    except Exception as e:
        LOG.exception(
            'Unhandled exception in validate_signature lambda. Error: %s',
            str(e),
        )
        raise
