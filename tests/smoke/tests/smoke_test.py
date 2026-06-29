"""Smoke tests against MiniStack.

Shallow on purpose: each test proves a service is alive and round-trips, shaped
after Forge's real data plane (tenant log bucket, webhook event queue + DLQ,
webhook secret in SSM, STS role assumption). These are NOT behavioral or
isolation tests - the emulator won't enforce IAM, so role assumption here proves
mechanics only.

Re-runnable without a reset: helpers below ignore "already exists".
"""

from __future__ import annotations

import json

import pytest
from botocore.exceptions import ClientError

pytestmark = pytest.mark.smoke


def _ignore_exists(fn, *args, **kwargs):
    try:
        return fn(*args, **kwargs)
    except ClientError as e:
        if e.response['Error']['Code'] in {
            'EntityAlreadyExists', 'ResourceAlreadyExistsException',
            'BucketAlreadyOwnedByYou',
        }:
            return None
        raise


def test_s3_tenant_bucket_roundtrip(client):
    s3 = client('s3')
    bucket = 'forge-smoke-tenant-logs'
    # us-east-1: no LocationConstraint
    _ignore_exists(s3.create_bucket, Bucket=bucket)
    s3.put_object(Bucket=bucket, Key='job/42/run.log', Body=b'hello')
    body = s3.get_object(Bucket=bucket, Key='job/42/run.log')['Body'].read()
    assert body == b'hello'


def test_sqs_event_queue_and_dlq(client):
    sqs = client('sqs')
    q = sqs.create_queue(QueueName='forge-smoke-events')['QueueUrl']
    sqs.create_queue(QueueName='forge-smoke-events-dlq')  # idempotent
    sqs.send_message(QueueUrl=q, MessageBody='ping')
    msgs = sqs.receive_message(
        QueueUrl=q, WaitTimeSeconds=2).get('Messages', [])
    assert msgs and msgs[0]['Body'] == 'ping'


def test_ssm_securestring_roundtrip(client):
    ssm = client('ssm')
    name = '/forge/smoke/webhook-secret'
    ssm.put_parameter(Name=name, Value='not-a-real-secret',
                      Type='SecureString', Overwrite=True)
    val = ssm.get_parameter(Name=name, WithDecryption=True)[
        'Parameter']['Value']
    assert val == 'not-a-real-secret'


def test_eventbridge_put_event(client):
    eb = client('events')
    resp = eb.put_events(Entries=[{
        'Source': 'forge.smoke', 'DetailType': 'smoke',
        'Detail': json.dumps({'ok': True}),
    }])
    assert resp['FailedEntryCount'] == 0


def test_cloudwatch_logs_group(client):
    logs = client('logs')
    name = '/forge/smoke'
    _ignore_exists(logs.create_log_group, logGroupName=name)
    found = logs.describe_log_groups(logGroupNamePrefix=name)['logGroups']
    assert any(g['logGroupName'] == name for g in found)


def test_sts_caller_identity(client):
    ident = client('sts').get_caller_identity()
    assert ident.get('Account')


def test_iam_role_create_and_assume(client):
    iam, sts = client('iam'), client('sts')
    trust = {
        'Version': '2012-10-17',
        'Statement': [{
            'Effect': 'Allow',
            'Principal': {'AWS': 'arn:aws:iam::000000000000:root'},
            'Action': 'sts:AssumeRole',
        }],
    }
    _ignore_exists(iam.create_role, RoleName='forge-smoke-tenant',
                   AssumeRolePolicyDocument=json.dumps(trust))
    arn = iam.get_role(RoleName='forge-smoke-tenant')['Role']['Arn']
    creds = sts.assume_role(RoleArn=arn, RoleSessionName='smoke')[
        'Credentials']
    # Mechanics only - the emulator does not enforce the trust policy.
    assert creds['AccessKeyId'] and creds['SecretAccessKey']
