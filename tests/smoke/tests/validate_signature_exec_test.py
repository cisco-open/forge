"""Real-handler MiniStack smoke test (Docker; host/CI only).

Deploys the ACTUAL webhook relay handler
(modules/platform/forge_runners/github_webhook_relay/source/lambda/validate_signature.py)
into MiniStack and exercises the webhook -> EventBridge plumbing end-to-end.

This is the integration counterpart to the moto unit tests: the unit tests pin
behaviour with mocks; this proves the real zip deploys, imports (boto3 from the
runtime), and publishes to a real EventBridge bus on the emulator.

Marked `lambda_exec` (needs Docker; excluded from the fast `-m smoke` run). Run:
    pytest -m lambda_exec -q
"""

from __future__ import annotations

import hashlib
import hmac
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
    'modules/platform/forge_runners/github_webhook_relay/source/lambda/'
    'validate_signature.py'
)
EVENT_BUS = 'forge-smoke-webhook-bus'
FUNCTION_NAME = 'forge-smoke-validate-signature'
WEBHOOK_SECRET = 'forge-smoke-webhook-secret'


def _zip_handler() -> bytes:
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, 'w') as z:
        z.writestr('validate_signature.py', HANDLER_FILE.read_text())
    return buf.getvalue()


def _ignore_exists(fn, *args, **kwargs):
    try:
        return fn(*args, **kwargs)
    except ClientError as e:
        if e.response['Error']['Code'] in {
            'ResourceAlreadyExistsException',
            'ResourceConflictException',
        }:
            return None
        raise


def _wait_until_active(lam, function_name: str):
    for _ in range(30):
        state = lam.get_function(FunctionName=function_name)[
            'Configuration'].get('State')
        if state in (None, 'Active'):
            return
        time.sleep(1)
    raise AssertionError(f'Lambda {function_name} did not become active')


def _deploy_validate_signature(client):
    assert HANDLER_FILE.exists(), f"handler not found: {HANDLER_FILE}"
    events = client('events')
    lam = client('lambda')

    _ignore_exists(events.create_event_bus, Name=EVENT_BUS)
    try:
        lam.create_function(
            FunctionName=FUNCTION_NAME,
            Runtime='python3.12',
            Role='arn:aws:iam::000000000000:role/forge-smoke-lambda',
            Handler='validate_signature.lambda_handler',
            Code={'ZipFile': _zip_handler()},
            Timeout=30,
            Environment={
                'Variables': {
                    'EVENT_BUS': EVENT_BUS,
                    'LOG_LEVEL': 'INFO',
                    'WEBHOOK_SECRET': WEBHOOK_SECRET,
                }
            },
        )
    except ClientError as e:
        if e.response['Error']['Code'] != 'ResourceConflictException':
            raise
        lam.update_function_code(
            FunctionName=FUNCTION_NAME,
            ZipFile=_zip_handler(),
        )
        lam.update_function_configuration(
            FunctionName=FUNCTION_NAME,
            Environment={
                'Variables': {
                    'EVENT_BUS': EVENT_BUS,
                    'LOG_LEVEL': 'INFO',
                    'WEBHOOK_SECRET': WEBHOOK_SECRET,
                }
            },
        )

    _wait_until_active(lam, FUNCTION_NAME)
    return lam


def _signed_event(*, lowercase_headers: bool = False, signature: str | None = None):
    body = json.dumps({'action': 'queued'})
    digest = hmac.new(WEBHOOK_SECRET.encode(), body.encode(),
                      hashlib.sha256).hexdigest()
    github_event_header = 'x-github-event' if lowercase_headers else 'X-GitHub-Event'
    signature_header = (
        'x-hub-signature-256'
        if lowercase_headers
        else 'X-Hub-Signature-256'
    )
    event = {
        'headers': {
            github_event_header: 'workflow_job',
        },
        'body': body,
        'isBase64Encoded': False,
    }
    if signature is None:
        event['headers'][signature_header] = f'sha256={digest}'
    elif signature:
        event['headers'][signature_header] = signature
    return event


def _invoke(lam, event):
    resp = lam.invoke(
        FunctionName=FUNCTION_NAME,
        Payload=json.dumps(event).encode(),
    )
    assert resp['StatusCode'] == 200
    payload = json.loads(resp['Payload'].read())
    return resp, payload


def test_real_validate_signature_publishes_to_eventbridge(client):
    lam = _deploy_validate_signature(client)

    # Real API Gateway v2 proxy shape with the same SHA-256 signature GitHub
    # sends for signed webhooks.
    resp, payload = _invoke(lam, _signed_event())
    assert 'FunctionError' not in resp
    # Handler returns {'statusCode': 200, 'body': 'Event forwarded'} on success.
    assert payload.get('statusCode') == 200, payload


def test_real_validate_signature_accepts_lowercase_headers(client):
    lam = _deploy_validate_signature(client)

    resp, payload = _invoke(lam, _signed_event(lowercase_headers=True))
    assert 'FunctionError' not in resp
    assert payload.get('statusCode') == 200, payload


def test_real_validate_signature_rejects_missing_signature(client):
    lam = _deploy_validate_signature(client)

    resp, payload = _invoke(lam, _signed_event(signature=''))
    assert resp.get('FunctionError') == 'Unhandled'
    assert payload.get('errorMessage') == 'Invalid signature'


def test_real_validate_signature_rejects_wrong_signature(client):
    lam = _deploy_validate_signature(client)

    resp, payload = _invoke(lam, _signed_event(signature='sha256=bad'))
    assert resp.get('FunctionError') == 'Unhandled'
    assert payload.get('errorMessage') == 'Invalid signature'
