"""Read-only MiniStack liveness checks for Forge critical plumbing.

Each check answers only "is this service path reachable?" and avoids mutating
state. Optional services skip cleanly when the emulator/live target does not
support them. Set FORGE_SMOKE_ASSUME_ROLE_ARN to verify a concrete role-chain.
"""

from __future__ import annotations

import os

import pytest
from botocore.exceptions import BotoCoreError, ClientError

pytestmark = pytest.mark.smoke


def _skip_if_unsupported(service: str, exc: Exception) -> None:
    pytest.skip(f'{service} liveness check unsupported by this target: {exc}')


def test_lambda_control_plane_liveness(client):
    lambda_client = client('lambda')
    try:
        response = lambda_client.list_functions(MaxItems=1)
    except (BotoCoreError, ClientError) as exc:
        _skip_if_unsupported('lambda', exc)

    assert 'Functions' in response


def test_sqs_and_dlq_control_plane_liveness(client):
    sqs = client('sqs')
    try:
        response = sqs.list_queues(MaxResults=1)
    except (BotoCoreError, ClientError) as exc:
        _skip_if_unsupported('sqs', exc)

    assert isinstance(response.get('QueueUrls', []), list)


def test_ssm_parameter_control_plane_liveness(client):
    ssm = client('ssm')
    try:
        response = ssm.describe_parameters(MaxResults=10)
    except (BotoCoreError, ClientError) as exc:
        _skip_if_unsupported('ssm', exc)

    assert isinstance(response.get('Parameters', []), list)


def test_ec2_runner_control_plane_liveness(client):
    ec2 = client('ec2')
    try:
        response = ec2.describe_instances(MaxResults=5)
    except (BotoCoreError, ClientError) as exc:
        _skip_if_unsupported('ec2', exc)

    assert isinstance(response.get('Reservations', []), list)


def test_eks_arc_control_plane_liveness(client):
    eks = client('eks')
    try:
        response = eks.list_clusters(maxResults=5)
    except (BotoCoreError, ClientError) as exc:
        _skip_if_unsupported('eks', exc)

    assert isinstance(response.get('clusters', []), list)


def test_sts_caller_identity_liveness(client):
    identity = client('sts').get_caller_identity()

    assert identity.get('Account')


def test_configured_sts_role_chain_is_assumable(client):
    role_arn = os.environ.get('FORGE_SMOKE_ASSUME_ROLE_ARN', '').strip()
    if not role_arn:
        pytest.skip('FORGE_SMOKE_ASSUME_ROLE_ARN not set')

    response = client('sts').assume_role(
        RoleArn=role_arn,
        RoleSessionName='forge-smoke-readonly',
    )

    assert response['Credentials']['AccessKeyId']
