"""Smoke-test fixtures pointed at MiniStack.

All clients talk to MiniStack on :4566 with dummy creds. If MiniStack is not
running, the suite SKIPS locally (so `pytest` is harmless) but FAILS when
FORGE_REQUIRE_MINISTACK=1 (set in CI) so a down emulator can't go green silently.
"""

from __future__ import annotations

import os

import boto3
import pytest

ENDPOINT = os.environ.get('AWS_ENDPOINT_URL', 'http://localhost:4566')
REGION = os.environ.get('AWS_DEFAULT_REGION', 'us-east-1')
# Dummy creds - emulator only, never real (see CodeGuard hardcoded-credentials).
_CREDS = {'aws_access_key_id': 'test', 'aws_secret_access_key': 'test'}


def make_client(service: str):
    return boto3.client(service, endpoint_url=ENDPOINT, region_name=REGION, **_CREDS)


@pytest.fixture(scope='session', autouse=True)
def _require_ministack():
    """Readiness gate for the whole suite."""
    try:
        make_client('sts').get_caller_identity()
    except Exception as exc:  # noqa: BLE001 - any failure means "not ready"
        msg = f"MiniStack not reachable at {ENDPOINT} ({exc}). Run `make up`."
        if os.environ.get('FORGE_REQUIRE_MINISTACK'):
            pytest.fail(msg)
        pytest.skip(msg)


@pytest.fixture
def client():
    """Return a factory: client('s3'), client('sqs'), ..."""
    return make_client
