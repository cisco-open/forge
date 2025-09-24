import hashlib
import hmac
import json
import os

import boto3

EVENT_BUS = os.environ['EVENT_BUS']
SECRET = os.environ.get('GITHUB_SECRET', '').encode()
eb = boto3.client('events')


def lambda_handler(event, _):
    signature = event['headers'].get('X-Hub-Signature-256', '')
    body = event['body']

    if SECRET:
        digest = hmac.new(SECRET, body.encode(), hashlib.sha256).hexdigest()
        if not signature.endswith(digest):
            return {'statusCode': 401, 'body': 'Invalid signature'}

    payload = json.loads(body)
    gh_event = event['headers'].get('X-GitHub-Event', 'unknown')
    action = payload.get('action', 'none')

    detail_type = f"github.{gh_event}.{action}"

    eb.put_events(
        Entries=[
            {
                'Source': 'github.webhook',
                'DetailType': detail_type,
                'Detail': json.dumps(payload),
                'EventBusName': EVENT_BUS
            }
        ]
    )

    return {'statusCode': 200, 'body': 'Event forwarded'}
