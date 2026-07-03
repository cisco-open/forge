"""Secret/payload hygiene in logs (register P0-6).

The full webhook body and an HMAC oracle should never land in CloudWatch.
These tests pin that logging boundary.
"""

from __future__ import annotations

import pytest
from conftest import requires_aws
from support import load_handler_module, make_apigw_v2_event, sign_sha256

pytestmark = [pytest.mark.security, requires_aws]

_BODY_MARKER = 'super-sensitive-payload-marker'


def _invoke(monkeypatch, bus_name, secret_env, event):
    monkeypatch.setenv('EVENT_BUS', bus_name)
    monkeypatch.setenv('LOG_LEVEL', 'INFO')
    for var in ('GITHUB_SECRET', 'WEBHOOK_SECRET'):
        monkeypatch.delenv(var, raising=False)
    for var, val in secret_env.items():
        monkeypatch.setenv(var, val)
    mod = load_handler_module('validate_signature')
    try:
        return mod.lambda_handler(event, None)
    except Exception:
        return None


def test_request_body_is_not_logged(
    monkeypatch, event_bus, webhook_secret, captured_logs
):
    import json

    body = json.dumps(
        {'action': 'queued', 'secret_field': _BODY_MARKER}
    ).encode()
    event = make_apigw_v2_event(body, sign_sha256(webhook_secret, body))
    _invoke(
        monkeypatch,
        event_bus['name'],
        {'WEBHOOK_SECRET': webhook_secret.decode()},
        event,
    )
    assert _BODY_MARKER not in captured_logs.text


def test_expected_digest_is_not_logged_on_mismatch(
    monkeypatch, event_bus, webhook_secret, captured_logs
):
    body = b'{"action":"queued"}'
    expected = sign_sha256(webhook_secret, body).split('=', 1)[1]
    event = make_apigw_v2_event(body, 'sha256=deadbeef')  # wrong -> mismatch
    _invoke(
        monkeypatch,
        event_bus['name'],
        {'WEBHOOK_SECRET': webhook_secret.decode()},
        event,
    )
    assert expected not in captured_logs.text
