"""Webhook signature validation — the security boundary at the front door.

Target: modules/platform/forge_runners/github_webhook_relay/source/lambda/validate_signature.py
(real handler, driven end-to-end under moto EventBridge).

The relay lambda must only forward payloads GitHub actually signed. A bypass
here lets an attacker inject events onto the EventBridge bus that downstream
consumers (job-log archival, etc.) act on (register P0-1/P0-2, threat-model).

These tests encode the intended security behavior and must pass.

Handler contract used here:
  * accept  -> returns {"statusCode": 200, ...}
  * reject  -> raises (ValueError("Invalid signature"))
The secret is read at module load from the environment; the loader re-imports
the module after each test sets env, so per-test secret config is honoured.
"""

from __future__ import annotations

import pytest
from conftest import requires_aws
from support import (load_handler_module, make_apigw_v2_event,
                     sign_sha1_legacy, sign_sha256, webhook_body)

pytestmark = [pytest.mark.security, requires_aws]


def _invoke(monkeypatch, bus_name, *, secret_env, event):
    """Set env (clearing unrelated secret vars), load the real handler fresh,
    invoke it. Returns the handler response or re-raises its exception.
    """
    monkeypatch.setenv('EVENT_BUS', bus_name)
    monkeypatch.setenv('LOG_LEVEL', 'INFO')
    for var in ('GITHUB_SECRET', 'WEBHOOK_SECRET'):
        monkeypatch.delenv(var, raising=False)
    for var, val in secret_env.items():
        monkeypatch.setenv(var, val)
    mod = load_handler_module('validate_signature')
    return mod.lambda_handler(event, None)


# --------------------------------------------------------------------------- #
# Behaviour when the deployed secret env var (WEBHOOK_SECRET) is set.
# --------------------------------------------------------------------------- #
def test_valid_signature_is_accepted(monkeypatch, event_bus, webhook_secret):
    body = webhook_body()
    sig = sign_sha256(webhook_secret, body)
    event = make_apigw_v2_event(body, sig)
    resp = _invoke(
        monkeypatch,
        event_bus['name'],
        secret_env={'WEBHOOK_SECRET': webhook_secret.decode()},
        event=event,
    )
    assert resp['statusCode'] == 200


def test_missing_signature_is_rejected(monkeypatch, event_bus, webhook_secret):
    event = make_apigw_v2_event(webhook_body(), signature_256=None)
    with pytest.raises(Exception):
        _invoke(
            monkeypatch,
            event_bus['name'],
            secret_env={'WEBHOOK_SECRET': webhook_secret.decode()},
            event=event,
        )


def test_tampered_body_is_rejected(monkeypatch, event_bus, webhook_secret):
    body = webhook_body(repo='acme/app')
    sig = sign_sha256(webhook_secret, body)
    tampered = body.replace(b'acme/app', b'attacker/app')
    event = make_apigw_v2_event(tampered, sig)
    with pytest.raises(Exception):
        _invoke(
            monkeypatch,
            event_bus['name'],
            secret_env={'WEBHOOK_SECRET': webhook_secret.decode()},
            event=event,
        )


def test_wrong_secret_is_rejected(monkeypatch, event_bus, webhook_secret):
    body = webhook_body()
    event = make_apigw_v2_event(body, sign_sha256(b'the-wrong-secret', body))
    with pytest.raises(Exception):
        _invoke(
            monkeypatch,
            event_bus['name'],
            secret_env={'WEBHOOK_SECRET': webhook_secret.decode()},
            event=event,
        )


def test_legacy_sha1_only_is_rejected(monkeypatch, event_bus, webhook_secret):
    body = webhook_body()
    event = make_apigw_v2_event(body, signature_256=None)
    event['headers']['X-Hub-Signature'] = sign_sha1_legacy(
        webhook_secret, body)
    with pytest.raises(Exception):
        _invoke(
            monkeypatch,
            event_bus['name'],
            secret_env={'WEBHOOK_SECRET': webhook_secret.decode()},
            event=event,
        )


# --------------------------------------------------------------------------- #
# The handler must validate against the secret env var Terraform sets.
# --------------------------------------------------------------------------- #
def test_forged_request_rejected_when_deploytime_secret_set(
    monkeypatch, event_bus, webhook_secret
):
    # Configure the secret the way the deployment does, and send an UNSIGNED
    # request. A correct handler rejects it.
    event = make_apigw_v2_event(webhook_body(), signature_256=None)
    with pytest.raises(Exception):
        _invoke(
            monkeypatch,
            event_bus['name'],
            secret_env={'WEBHOOK_SECRET': webhook_secret.decode()},
            event=event,
        )


# --------------------------------------------------------------------------- #
# Comparison must be constant-time and structurally correct. A malformed or
# prefixed signature must be rejected even when it ends in the correct digest.
# --------------------------------------------------------------------------- #
@pytest.mark.parametrize('prefix', ['', 'garbage', 'sha1=', 'sha256= '])
def test_malformed_signature_is_rejected(
    monkeypatch, event_bus, webhook_secret, prefix
):
    body = webhook_body()
    raw_digest = sign_sha256(webhook_secret, body).split('=', 1)[1]
    # Valid digest but wrong/garbage scheme prefix: endswith() accepts it today.
    event = make_apigw_v2_event(body, f"{prefix}{raw_digest}")
    with pytest.raises(Exception):
        _invoke(
            monkeypatch,
            event_bus['name'],
            secret_env={'WEBHOOK_SECRET': webhook_secret.decode()},
            event=event,
        )


# --------------------------------------------------------------------------- #
# Under API Gateway v2 payload format 2.0 header keys are lowercased. A real
# lowercase header must still validate and accept a properly signed body.
# --------------------------------------------------------------------------- #
def test_valid_signature_with_lowercase_headers_is_accepted(
    monkeypatch, event_bus, webhook_secret
):
    body = webhook_body()
    sig = sign_sha256(webhook_secret, body)
    event = make_apigw_v2_event(body, sig, lowercase_headers=True)
    resp = _invoke(
        monkeypatch,
        event_bus['name'],
        secret_env={'WEBHOOK_SECRET': webhook_secret.decode()},
        event=event,
    )
    assert resp['statusCode'] == 200
