"""Smoke-test fixtures pointed at MiniStack.

All clients talk to MiniStack on :4566 with dummy creds. If MiniStack is not
running, the suite SKIPS locally (so `pytest` is harmless) but FAILS when
FORGE_REQUIRE_MINISTACK=1 (set in CI) so a down emulator can't go green silently.
"""

from __future__ import annotations

import json
import os

import boto3
import pytest
from botocore.exceptions import BotoCoreError, ClientError

ENDPOINT = os.environ.get('AWS_ENDPOINT_URL', 'http://localhost:4566')
REGION = os.environ.get('AWS_DEFAULT_REGION', 'us-east-1')
# Dummy creds - emulator only, never real (see CodeGuard hardcoded-credentials).
_CREDS = {'aws_access_key_id': 'test', 'aws_secret_access_key': 'test'}
_DEFAULT_SMOKE_ROLE_NAME = 'forge-smoke-readonly'


def make_client(service: str):
    return boto3.client(service, endpoint_url=ENDPOINT, region_name=REGION, **_CREDS)


def _role_name_from_arn(role_arn: str) -> str:
    return role_arn.rsplit('/', 1)[-1]


def _trust_policy() -> str:
    return json.dumps({
        'Version': '2012-10-17',
        'Statement': [{
            'Effect': 'Allow',
            'Principal': {'AWS': '*'},
            'Action': 'sts:AssumeRole',
        }],
    })


def _ensure_emulator_role(role_arn: str) -> None:
    role_name = _role_name_from_arn(role_arn)
    iam = make_client('iam')
    try:
        iam.get_role(RoleName=role_name)
    except ClientError as exc:
        code = exc.response.get('Error', {}).get('Code')
        if code not in {'NoSuchEntity', 'NoSuchEntityException'}:
            raise
        iam.create_role(
            RoleName=role_name,
            AssumeRolePolicyDocument=_trust_policy(),
        )


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


@pytest.fixture(scope='session')
def smoke_assume_role_arn() -> str:
    """Return an assumable role ARN for MiniStack without requiring live AWS."""
    account = make_client('sts').get_caller_identity()['Account']
    role_arn = f'arn:aws:iam::{account}:role/{_DEFAULT_SMOKE_ROLE_NAME}'

    try:
        _ensure_emulator_role(role_arn)
    except (BotoCoreError, ClientError):
        # MiniStack-compatible emulators differ on IAM strictness. STS is the
        # behavior under test, so let assume_role below be authoritative.
        pass

    return role_arn
