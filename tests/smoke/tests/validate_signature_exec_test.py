"""Real-handler MiniStack smoke test (Docker; host/CI only).

Deploys the ACTUAL webhook relay handler
(modules/integrations/github_webhook_relay_source/lambda/validate_signature.py)
into MiniStack and exercises the webhook -> EventBridge plumbing end-to-end.

This is the integration counterpart to the moto unit tests: the unit tests pin
behaviour with mocks; this proves the real zip deploys, imports (boto3 from the
runtime), and publishes to a real EventBridge bus on the emulator.

Marked `lambda_exec` (needs Docker; excluded from the fast `-m smoke` run). Run:
    pytest -m lambda_exec -q
"""

from __future__ import annotations

import io
import json
import time
import zipfile
from pathlib import Path

import pytest
from botocore.exceptions import ClientError

pytestmark = pytest.mark.lambda_exec

# Real handler source, relative to repo root (tests/smoke/tests -> parents[3]).
_REPO_ROOT = Path(__file__).resolve().parents[3]
HANDLER_FILE = _REPO_ROOT / (
    'modules/integrations/github_webhook_relay_source/lambda/'
    'validate_signature.py'
)


def _zip_handler() -> bytes:
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, 'w') as z:
        z.writestr('validate_signature.py', HANDLER_FILE.read_text())
    return buf.getvalue()


def test_real_validate_signature_publishes_to_eventbridge(client):
    assert HANDLER_FILE.exists(), f"handler not found: {HANDLER_FILE}"
    events = client('events')
    lam = client('lambda')
    bus = 'forge-smoke-webhook-bus'
    fn = 'forge-smoke-validate-signature'

    events.create_event_bus(Name=bus)
    try:
        lam.create_function(
            FunctionName=fn,
            Runtime='python3.12',
            Role='arn:aws:iam::000000000000:role/forge-smoke-lambda',
            Handler='validate_signature.lambda_handler',
            Code={'ZipFile': _zip_handler()},
            Timeout=30,
            Environment={'Variables': {'EVENT_BUS': bus, 'LOG_LEVEL': 'INFO'}},
        )
    except ClientError as e:
        if e.response['Error']['Code'] != 'ResourceConflictException':
            raise

    for _ in range(30):
        state = lam.get_function(FunctionName=fn)['Configuration'].get('State')
        if state in (None, 'Active'):
            break
        time.sleep(1)

    # Real API Gateway v2 proxy shape. No GITHUB_SECRET set -> handler forwards
    # (this is exactly the prod fail-open path documented as P0-1; here it lets
    # us assert the publish plumbing works without a signing secret).
    event = {
        'headers': {'X-GitHub-Event': 'workflow_job'},
        'body': json.dumps({'action': 'queued'}),
        'isBase64Encoded': False,
    }
    resp = lam.invoke(FunctionName=fn, Payload=json.dumps(event).encode())
    assert resp['StatusCode'] == 200
    payload = json.loads(resp['Payload'].read())
    # Handler returns {'statusCode': 200, 'body': 'Event forwarded'} on success.
    assert payload.get('statusCode') == 200, payload
