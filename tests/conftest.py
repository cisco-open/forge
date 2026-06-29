"""Pytest fixtures for ForgeMT first-party lambda unit tests.

Design rules:
  * No live AWS, no network, no sleeps. Everything is mocked with moto.
  * AWS credentials are forced to dummy values so a misconfigured test can
    never reach a real account.
  * Several handlers create boto3 clients at MODULE LOAD (e.g.
    validate_signature: `eb = boto3.client('events')`). Tests therefore must
    enter the `aws` fixture and set env BEFORE calling
    support.load_handler_module(). The fixtures here only set up infrastructure;
    importing the handler is left to each test so import order is explicit.
"""

from __future__ import annotations

import logging
import sys
from pathlib import Path

import pytest

# Make `support` importable as a top-level package regardless of pytest's
# rootdir handling.
sys.path.insert(0, str(Path(__file__).resolve().parent))

try:
    import boto3
    from moto import mock_aws

    _HAVE_AWS_TEST_DEPS = True
except ImportError:  # pragma: no cover - env without boto3/moto (e.g. Cowork VM)
    boto3 = None  # type: ignore
    mock_aws = None  # type: ignore
    _HAVE_AWS_TEST_DEPS = False


# An obviously-fake secret. Never a real-looking credential. Used to sign test
# webhook payloads.
TEST_WEBHOOK_SECRET = b'forge-test-not-a-real-secret'
AWS_REGION = 'us-west-2'
AWS_ACCOUNT = '123456789012'

# Skip the whole AWS-dependent suite cleanly when boto3/moto aren't installed
# (the Cowork VM has no PyPI access). CI installs tests/requirements-dev.txt and
# runs everything.
requires_aws = pytest.mark.skipif(
    not _HAVE_AWS_TEST_DEPS,
    reason='boto3/moto not installed; run in CI or `pip install -r '
    'tests/requirements-dev.txt`',
)


@pytest.fixture(autouse=True)
def _block_real_aws(monkeypatch):
    """Force dummy creds + region so nothing can hit a real account."""
    for var, val in {
        'AWS_ACCESS_KEY_ID': 'testing',
        'AWS_SECRET_ACCESS_KEY': 'testing',
        'AWS_SECURITY_TOKEN': 'testing',
        'AWS_SESSION_TOKEN': 'testing',
        'AWS_DEFAULT_REGION': AWS_REGION,
        'AWS_REGION': AWS_REGION,
    }.items():
        monkeypatch.setenv(var, val)


@pytest.fixture
def aws(_block_real_aws):
    """Activate moto for the duration of a test."""
    if not _HAVE_AWS_TEST_DEPS:
        pytest.skip('boto3/moto not installed')
    with mock_aws():
        yield


@pytest.fixture
def event_bus(aws):
    """An EventBridge bus, as the webhook relay forwards to (register A0)."""
    client = boto3.client('events', region_name=AWS_REGION)
    name = 'forge-webhook-relay-source'
    client.create_event_bus(Name=name)
    return {'client': client, 'name': name}


@pytest.fixture
def sqs(aws):
    """A main queue wired to a DLQ via redrive policy (job-logs / trust)."""
    client = boto3.client('sqs', region_name=AWS_REGION)
    dlq = client.create_queue(QueueName='forge-jobs-dlq')['QueueUrl']
    dlq_arn = client.get_queue_attributes(
        QueueUrl=dlq, AttributeNames=['QueueArn']
    )['Attributes']['QueueArn']
    main = client.create_queue(
        QueueName='forge-jobs',
        Attributes={
            'RedrivePolicy': (
                '{"deadLetterTargetArn":"%s","maxReceiveCount":"10"}' % dlq_arn
            )
        },
    )['QueueUrl']
    main_arn = client.get_queue_attributes(
        QueueUrl=main, AttributeNames=['QueueArn']
    )['Attributes']['QueueArn']
    return {
        'client': client,
        'main_url': main,
        'main_arn': main_arn,
        'dlq_url': dlq,
        'dlq_arn': dlq_arn,
    }


@pytest.fixture
def s3_kms(aws):
    """Per-tenant log buckets + a KMS key, mirroring the deployment model
    (one bucket per tenant deployment, register A6/P1-8). Two tenants so
    isolation tests can prove writes don't cross over.
    """
    s3 = boto3.client('s3', region_name=AWS_REGION)
    kms = boto3.client('kms', region_name=AWS_REGION)
    key_arn = kms.create_key(Description='forge-test-gh-logs')['KeyMetadata'][
        'Arn'
    ]
    buckets = {}
    for tenant in ('alpha', 'bravo'):
        name = f"forge-tenant-{tenant}-forge-gh-logs-{AWS_ACCOUNT}"
        s3.create_bucket(
            Bucket=name,
            CreateBucketConfiguration={'LocationConstraint': AWS_REGION},
        )
        buckets[tenant] = name
    return {'s3': s3, 'kms': kms, 'key_arn': key_arn, 'buckets': buckets}


@pytest.fixture
def ssm(aws):
    """SSM SecureString params, as job_log_archiver reads (register A1)."""
    client = boto3.client('ssm', region_name=AWS_REGION)
    return {'client': client}


@pytest.fixture
def captured_logs(caplog):
    """Capture log records so hygiene tests can assert secrets never appear.

    Logging was widened in v2.0.0; this pins 'no secret/token in logs' going
    forward (register P0-6).
    """
    caplog.set_level(logging.DEBUG)
    return caplog


@pytest.fixture
def webhook_secret():
    return TEST_WEBHOOK_SECRET
