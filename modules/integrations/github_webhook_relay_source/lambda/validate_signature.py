import hashlib
import hmac
import json
import logging
import os

import boto3

EVENT_BUS = os.environ['EVENT_BUS']
SECRET = os.environ['WEBHOOK_SECRET'].encode()
eb = boto3.client('events')

LOG = logging.getLogger()
level_str = os.environ.get('LOG_LEVEL', 'INFO').upper()
LOG.setLevel(getattr(logging, level_str, logging.INFO))


def lambda_handler(event, _):
    try:
        headers = {
            str(key).lower(): value
            for key, value in (event.get('headers') or {}).items()
        }
        signature = headers.get('x-hub-signature-256', '')
        body = event['body']
        gh_event = headers.get('x-github-event', 'unknown')
        LOG.info(
            'Received GitHub webhook event=%s body_bytes=%d signature_present=%s',
            gh_event,
            len(body.encode()),
            bool(signature),
        )

        digest = hmac.new(SECRET, body.encode(),
                          hashlib.sha256).hexdigest()
        expected_signature = f"sha256={digest}"
        if not hmac.compare_digest(signature, expected_signature):
            LOG.warning('Signature mismatch for GitHub webhook event=%s',
                        gh_event)
            raise ValueError('Invalid signature')

        payload = json.loads(body)
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
