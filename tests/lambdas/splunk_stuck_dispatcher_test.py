"""Splunk stuck workflow-job dispatcher: receiver Lambda logic.

Target: modules/integrations/splunk_stuck_workflow_job_dispatcher/lambda/handler.py

The receiver normalizes Splunk batch results, groups them by SQS queue, then
uses live EC2 state to decide what to do per stuck job:
  * job_executed  -> an EC2 already carries the job's `ghr:workflow_job_url`
                     tag, so redelivery already happened; skip.
  * free_runner   -> a pending/running EC2 with NO workflow_job_url tag exists
                     for that runner pool, so the job will probably be picked
                     up without redelivery; skip and wait for the next Splunk
                     alert. Cap skips at the number of free runners per queue.
  * otherwise     -> write to the DynamoDB dedupe/work table for the worker
                     Lambda to actually call GitHub redelivery.

Tests below pin every branch (token check, missing fields, URL match, the per-
queue free-runner cap, EC2 error fail-open, dedupe-once write).
"""

from __future__ import annotations

import importlib
import json
import sys
from pathlib import Path

import pytest
from conftest import AWS_REGION, requires_aws

pytestmark = requires_aws

LAMBDA_DIR = Path(__file__).resolve().parents[2].joinpath(
    'modules',
    'integrations',
    'splunk_stuck_workflow_job_dispatcher',
    'lambda',
)
WEBHOOK_TOKEN = 'test-token-xyz'
DEDUPE_TABLE = 'splunk-dispatcher-dedupe-test'


# --------------------------------------------------------------------------- #
# Test helpers
# --------------------------------------------------------------------------- #
def _load_handler(monkeypatch):
    """Import the receiver Lambda with its lambda/ dir on sys.path.

    The file is named `handler.py` so we sys.modules.pop it first to make
    re-imports clean across tests.
    """
    src = str(LAMBDA_DIR)
    if src not in sys.path:
        sys.path.insert(0, src)
    monkeypatch.setenv('WEBHOOK_TOKEN', WEBHOOK_TOKEN)
    monkeypatch.setenv('DEDUPE_TABLE', DEDUPE_TABLE)
    monkeypatch.setenv('DEDUPE_TTL_SECONDS', '1800')
    sys.modules.pop('handler', None)
    return importlib.import_module('handler')


def _load_worker(monkeypatch):
    """Import the worker Lambda with its lambda/ dir on sys.path."""
    src = str(LAMBDA_DIR)
    if src not in sys.path:
        sys.path.insert(0, src)
    monkeypatch.setenv('DEDUPE_TABLE', DEDUPE_TABLE)
    sys.modules.pop('worker', None)
    return importlib.import_module('worker')


def _create_dedupe_table(boto3_mod):
    ddb = boto3_mod.client('dynamodb', region_name=AWS_REGION)
    ddb.create_table(
        TableName=DEDUPE_TABLE,
        AttributeDefinitions=[
            {'AttributeName': 'dedupe_key', 'AttributeType': 'S'},
        ],
        KeySchema=[{'AttributeName': 'dedupe_key', 'KeyType': 'HASH'}],
        BillingMode='PAY_PER_REQUEST',
    )
    return ddb


def _run_runner_instance(ec2, *, runner_name, workflow_job_url='',
                         state='running'):
    """Boot a single mock EC2 instance tagged like a real GHR runner."""
    tags = [{'Key': 'Name', 'Value': runner_name}]
    if workflow_job_url:
        tags.append(
            {'Key': 'ghr:workflow_job_url', 'Value': workflow_job_url}
        )
    res = ec2.run_instances(
        ImageId='ami-12345678',
        MinCount=1,
        MaxCount=1,
        InstanceType='t3.small',
        TagSpecifications=[{'ResourceType': 'instance', 'Tags': tags}],
    )
    instance_id = res['Instances'][0]['InstanceId']
    if state == 'stopped':
        ec2.stop_instances(InstanceIds=[instance_id])
    elif state == 'terminated':
        ec2.terminate_instances(InstanceIds=[instance_id])
    return instance_id


def _splunk_result(*, workflow_job_id, repository='acme/app',
                   queue_name='acgw-usw2-sl-small-queued-builds',
                   region=AWS_REGION, workflow_job_url='', tenant='acgw',
                   github_delivery='guid-1'):
    return {
        'workflowJobId': workflow_job_id,
        'repository': repository,
        'forgecicd_tenant': tenant,
        'aws_region': region,
        'github_delivery': github_delivery,
        'queued_url': (
            f'https://sqs.{region}.amazonaws.com/123456789012/{queue_name}'
        ),
        'workflow_job_url': workflow_job_url,
        'runner_labels': ['env:ops-prod', 'self-hosted', 'type:small', 'x64'],
        'job_name': 'build',
        'run_id': 1,
        'run_attempt': 1,
        'workflow_name': 'ci',
    }


def _apigw_event(results, *, token=WEBHOOK_TOKEN, method='POST'):
    return {
        'version': '2.0',
        'routeKey': 'POST /splunk/{token}',
        'pathParameters': {'token': token},
        'headers': {'content-type': 'application/json'},
        'body': json.dumps({'results': results}),
        'isBase64Encoded': False,
        'requestContext': {
            'requestId': 'req-1',
            'http': {'method': method, 'path': '/splunk/x'},
        },
    }


# --------------------------------------------------------------------------- #
# Pure helpers
# --------------------------------------------------------------------------- #
def test_parse_queued_url_returns_queue_name(monkeypatch):
    mod = _load_handler(monkeypatch)
    url = (
        'https://sqs.us-west-2.amazonaws.com/166060576821/'
        'acgw-usw2-sl-small-queued-builds'
    )
    assert mod.parse_queued_url(url) == 'acgw-usw2-sl-small-queued-builds'


def test_parse_queued_url_empty_returns_empty(monkeypatch):
    mod = _load_handler(monkeypatch)
    assert mod.parse_queued_url('') == ''


def test_parse_queued_url_invalid_url_returns_empty(monkeypatch):
    mod = _load_handler(monkeypatch)
    assert mod.parse_queued_url('/\n/\n]\n?') == ''


def test_runner_name_from_queue_strips_suffix_and_appends_runner_suffix(
    monkeypatch,
):
    mod = _load_handler(monkeypatch)
    actual = mod.runner_name_from_queue('acgw-usw2-sl-small-queued-builds')
    assert actual == 'acgw-usw2-sl-small-action-runner'


def test_runner_name_from_queue_handles_unexpected_suffix(monkeypatch):
    mod = _load_handler(monkeypatch)
    # If the queue name doesn't carry the -queued-builds suffix we still
    # append -action-runner so the tag filter is well-formed.
    actual = mod.runner_name_from_queue('something-else')
    assert actual == 'something-else-action-runner'


def test_dedupe_key_includes_tenant_region_repo_job(monkeypatch):
    mod = _load_handler(monkeypatch)
    payload = {
        'tenant': 'acgw',
        'aws_region': 'us-west-2',
        'repository': 'acme/app',
        'workflow_job_id': 42,
    }
    assert mod.dedupe_key(payload) == 'acgw#us-west-2#acme/app#42'


def test_split_multivalue_dedupes_preserving_order(monkeypatch):
    mod = _load_handler(monkeypatch)

    assert mod.split_multivalue(
        ' self-hosted, x64\nx64  type:small,self-hosted '
    ) == ['self-hosted', 'x64', 'type:small']


def test_normalize_result_raises_when_required_fields_missing(monkeypatch):
    mod = _load_handler(monkeypatch)
    # No queued_url, no github_delivery -> ValueError listing both.
    with pytest.raises(ValueError) as exc:
        mod.normalize_result({
            'workflowJobId': 1,
            'forgecicd_tenant': 'acgw',
            'aws_region': AWS_REGION,
        })
    msg = str(exc.value)
    assert 'queued_url' in msg
    assert 'github_delivery' in msg


def test_worker_normalizes_scalar_github_delivery_as_single_reference(
    monkeypatch,
):
    mod = _load_worker(monkeypatch)
    guid = 'f1234567-89ab-4cde-8123-456789abcdef'

    assert mod.normalize_delivery_references(guid) == ([], [guid])
    assert mod.normalize_delivery_references('123456') == (['123456'], [])


def test_process_results_classifies_and_queues_without_lambda_wrapper(
    monkeypatch,
):
    mod = _load_handler(monkeypatch)
    executed_url = 'https://github.com/acme/app/actions/runs/9/job/900'
    queued_writes = []

    def _find_runner_instances(region, runner_name):
        assert region == AWS_REGION
        assert runner_name == 'acgw-usw2-sl-small-action-runner'
        return [
            {
                'instance_id': 'i-executed',
                'state': 'terminated',
                'workflow_job_url': executed_url,
            },
            {
                'instance_id': 'i-free',
                'state': 'running',
                'workflow_job_url': '',
            },
        ]

    def _put_pending_work_once(key, payload):
        queued_writes.append((key, payload))
        return True

    monkeypatch.setattr(mod, 'find_runner_instances', _find_runner_instances)
    monkeypatch.setattr(mod, 'put_pending_work_once', _put_pending_work_once)

    result = mod.process_results([
        _splunk_result(workflow_job_id=900, workflow_job_url=executed_url),
        _splunk_result(
            workflow_job_id=901,
            workflow_job_url='https://github.com/acme/app/actions/runs/9/job/901',
        ),
        _splunk_result(
            workflow_job_id=902,
            workflow_job_url='https://github.com/acme/app/actions/runs/9/job/902',
        ),
    ])

    assert result['skipped'] == [
        {
            'key': 'acgw#us-west-2#acme/app#900',
            'reason': 'job_executed',
            'workflow_job_url': executed_url,
            'instance_id': 'i-executed',
            'state': 'terminated',
        },
        {
            'key': 'acgw#us-west-2#acme/app#901',
            'reason': 'free_runner',
            'runner_name': 'acgw-usw2-sl-small-action-runner',
            'instance_id': 'i-free',
            'state': 'running',
        },
    ]
    assert result['queued'] == [{
        'key': 'acgw#us-west-2#acme/app#902',
        'workflow_job_id': 902,
        'runner_labels': ['env:ops-prod', 'self-hosted', 'type:small', 'x64'],
    }]
    assert queued_writes[0][0] == 'acgw#us-west-2#acme/app#902'


# --------------------------------------------------------------------------- #
# validate_request / auth
# --------------------------------------------------------------------------- #
def test_invalid_token_returns_403(monkeypatch, aws):
    import boto3
    _create_dedupe_table(boto3)
    mod = _load_handler(monkeypatch)
    event = _apigw_event([_splunk_result(workflow_job_id=1)], token='wrong')
    resp = mod.lambda_handler(event, None)
    assert resp['statusCode'] == 403


def test_non_post_method_returns_403(monkeypatch, aws):
    import boto3
    _create_dedupe_table(boto3)
    mod = _load_handler(monkeypatch)
    event = _apigw_event([_splunk_result(workflow_job_id=1)], method='GET')
    resp = mod.lambda_handler(event, None)
    assert resp['statusCode'] == 403


def test_empty_results_returns_200_noop(monkeypatch, aws):
    import boto3
    _create_dedupe_table(boto3)
    mod = _load_handler(monkeypatch)
    event = _apigw_event([])
    resp = mod.lambda_handler(event, None)
    assert resp['statusCode'] == 200


# --------------------------------------------------------------------------- #
# Runner-aware decisions (the new logic)
# --------------------------------------------------------------------------- #
def test_no_ec2_instances_queues_redelivery(monkeypatch, aws):
    import boto3
    _create_dedupe_table(boto3)
    mod = _load_handler(monkeypatch)
    event = _apigw_event([
        _splunk_result(
            workflow_job_id=100,
            workflow_job_url='https://github.com/acme/app/actions/runs/1/job/100',
        )
    ])
    resp = mod.lambda_handler(event, None)
    body = json.loads(resp['body'])
    assert resp['statusCode'] == 202
    assert len(body['queued']) == 1
    assert body['queued'][0]['workflow_job_id'] == 100
    assert body['skipped'] == []


def test_matching_workflow_job_url_skips_as_executed(monkeypatch, aws):
    import boto3
    ec2 = boto3.client('ec2', region_name=AWS_REGION)
    _create_dedupe_table(boto3)
    job_url = 'https://github.com/acme/app/actions/runs/1/job/200'
    _run_runner_instance(
        ec2,
        runner_name='acgw-usw2-sl-small-action-runner',
        workflow_job_url=job_url,
    )
    mod = _load_handler(monkeypatch)
    event = _apigw_event([
        _splunk_result(workflow_job_id=200, workflow_job_url=job_url)
    ])
    resp = mod.lambda_handler(event, None)
    body = json.loads(resp['body'])
    assert body['queued'] == []
    assert len(body['skipped']) == 1
    assert body['skipped'][0]['reason'] == 'job_executed'
    assert body['skipped'][0]['workflow_job_url'] == job_url


def test_free_runner_caps_skip_count_per_queue(monkeypatch, aws):
    """1 free EC2 + 2 stuck jobs -> 1 free_runner skip, 1 queued."""
    import boto3
    ec2 = boto3.client('ec2', region_name=AWS_REGION)
    _create_dedupe_table(boto3)
    # One free runner (no workflow_job_url tag).
    _run_runner_instance(
        ec2, runner_name='acgw-usw2-sl-small-action-runner',
    )
    mod = _load_handler(monkeypatch)
    event = _apigw_event([
        _splunk_result(
            workflow_job_id=301,
            workflow_job_url='https://github.com/acme/app/actions/runs/1/job/301',
        ),
        _splunk_result(
            workflow_job_id=302,
            workflow_job_url='https://github.com/acme/app/actions/runs/1/job/302',
        ),
    ])
    resp = mod.lambda_handler(event, None)
    body = json.loads(resp['body'])
    assert len(body['queued']) == 1
    assert len(body['skipped']) == 1
    assert body['skipped'][0]['reason'] == 'free_runner'
    # Order is preserved: first stuck job claimed the free runner.
    assert body['queued'][0]['workflow_job_id'] == 302


def test_busy_runners_do_not_count_as_free(monkeypatch, aws):
    """2 EC2s, both already tagged with OTHER URLs -> both jobs queued."""
    import boto3
    ec2 = boto3.client('ec2', region_name=AWS_REGION)
    _create_dedupe_table(boto3)
    _run_runner_instance(
        ec2,
        runner_name='acgw-usw2-sl-small-action-runner',
        workflow_job_url='https://github.com/acme/app/actions/runs/9/job/900',
    )
    _run_runner_instance(
        ec2,
        runner_name='acgw-usw2-sl-small-action-runner',
        workflow_job_url='https://github.com/acme/app/actions/runs/9/job/901',
    )
    mod = _load_handler(monkeypatch)
    event = _apigw_event([
        _splunk_result(
            workflow_job_id=401,
            workflow_job_url='https://github.com/acme/app/actions/runs/4/job/401',
        ),
        _splunk_result(
            workflow_job_id=402,
            workflow_job_url='https://github.com/acme/app/actions/runs/4/job/402',
        ),
    ])
    resp = mod.lambda_handler(event, None)
    body = json.loads(resp['body'])
    assert len(body['queued']) == 2
    assert body['skipped'] == []


def test_terminated_runner_does_not_count_as_free(monkeypatch, aws):
    """A terminated EC2 with the right Name tag must NOT block redelivery."""
    import boto3
    ec2 = boto3.client('ec2', region_name=AWS_REGION)
    _create_dedupe_table(boto3)
    _run_runner_instance(
        ec2,
        runner_name='acgw-usw2-sl-small-action-runner',
        state='terminated',
    )
    mod = _load_handler(monkeypatch)
    event = _apigw_event([
        _splunk_result(
            workflow_job_id=500,
            workflow_job_url='https://github.com/acme/app/actions/runs/5/job/500',
        )
    ])
    resp = mod.lambda_handler(event, None)
    body = json.loads(resp['body'])
    assert len(body['queued']) == 1
    assert body['skipped'] == []


def test_terminated_runner_with_matching_url_skips_as_executed(monkeypatch, aws):
    """Even when terminated, an EC2 tagged with the job's workflow_job_url
    means the runner already picked up the job. Do not retrigger redelivery
    and do not write to DynamoDB.
    """
    import boto3
    ec2 = boto3.client('ec2', region_name=AWS_REGION)
    _create_dedupe_table(boto3)
    job_url = 'https://github.com/acme/app/actions/runs/5/job/550'
    _run_runner_instance(
        ec2,
        runner_name='acgw-usw2-sl-small-action-runner',
        workflow_job_url=job_url,
        state='terminated',
    )
    mod = _load_handler(monkeypatch)
    event = _apigw_event([
        _splunk_result(workflow_job_id=550, workflow_job_url=job_url)
    ])
    resp = mod.lambda_handler(event, None)
    body = json.loads(resp['body'])
    assert body['queued'] == []
    assert len(body['skipped']) == 1
    assert body['skipped'][0]['reason'] == 'job_executed'
    assert body['skipped'][0]['state'] == 'terminated'

    # Confirm nothing was written to the dedupe / work table.
    ddb = boto3.client('dynamodb', region_name=AWS_REGION)
    scan = ddb.scan(TableName=DEDUPE_TABLE)
    assert scan['Count'] == 0


def test_different_queues_dont_share_free_runner_budget(monkeypatch, aws):
    """A free runner for queue A must not absorb a stuck job from queue B."""
    import boto3
    ec2 = boto3.client('ec2', region_name=AWS_REGION)
    _create_dedupe_table(boto3)
    _run_runner_instance(
        ec2, runner_name='acgw-usw2-sl-small-action-runner',
    )
    mod = _load_handler(monkeypatch)
    event = _apigw_event([
        _splunk_result(
            workflow_job_id=601,
            queue_name='acgw-usw2-sl-small-queued-builds',
            workflow_job_url='https://github.com/acme/app/actions/runs/6/job/601',
        ),
        _splunk_result(
            workflow_job_id=602,
            # Different queue/pool -> EC2 lookup finds nothing.
            queue_name='acgw-usw2-sl-large-queued-builds',
            workflow_job_url='https://github.com/acme/app/actions/runs/6/job/602',
        ),
    ])
    resp = mod.lambda_handler(event, None)
    body = json.loads(resp['body'])
    queued_ids = {q['workflow_job_id'] for q in body['queued']}
    skipped_reasons = [s['reason'] for s in body['skipped']]
    assert 602 in queued_ids  # other queue is unaffected
    assert skipped_reasons == ['free_runner']  # only the small-queue job


def test_duplicate_dedupe_key_is_skipped(monkeypatch, aws):
    """Two Splunk results with the same dedupe key -> one queued, one duplicate."""
    import boto3
    _create_dedupe_table(boto3)
    mod = _load_handler(monkeypatch)
    event = _apigw_event([
        _splunk_result(
            workflow_job_id=700,
            workflow_job_url='https://github.com/acme/app/actions/runs/7/job/700',
        ),
        _splunk_result(
            workflow_job_id=700,
            workflow_job_url='https://github.com/acme/app/actions/runs/7/job/700',
        ),
    ])
    resp = mod.lambda_handler(event, None)
    body = json.loads(resp['body'])
    assert len(body['queued']) == 1
    assert len(body['skipped']) == 1
    assert body['skipped'][0]['reason'] == 'duplicate'


def test_expired_dedupe_key_can_be_requeued(monkeypatch, aws):
    import boto3
    ddb = _create_dedupe_table(boto3)
    mod = _load_handler(monkeypatch)
    monkeypatch.setattr(mod.time, 'time', lambda: 1000)
    key = 'acgw#us-west-2#acme/app#900'
    ddb.put_item(
        TableName=DEDUPE_TABLE,
        Item={
            'dedupe_key': {'S': key},
            'created_at': {'N': '1'},
            'expires_at': {'N': '900'},
            'payload': {'S': '{}'},
            'payload_hash': {'S': 'old'},
            'status': {'S': 'completed'},
        },
    )
    payload = {
        'tenant': 'acgw',
        'aws_region': 'us-west-2',
        'repository': 'acme/app',
        'workflow_job_id': 900,
    }

    assert mod.put_pending_work_once(key, payload)

    item = ddb.get_item(
        TableName=DEDUPE_TABLE,
        Key={'dedupe_key': {'S': key}},
    )['Item']
    assert item['status']['S'] == 'pending'
    assert item['expires_at']['N'] == '2800'


def test_ec2_describe_failure_fails_open(monkeypatch, aws):
    """If EC2 DescribeInstances raises, the receiver must still queue the job."""
    import boto3
    from botocore.exceptions import ClientError
    _create_dedupe_table(boto3)
    mod = _load_handler(monkeypatch)

    def _boom(_region, _runner):
        raise ClientError(
            {'Error': {'Code': 'UnauthorizedOperation', 'Message': 'no'}},
            'DescribeInstances',
        )

    monkeypatch.setattr(mod, 'find_runner_instances', _boom)
    event = _apigw_event([
        _splunk_result(
            workflow_job_id=800,
            workflow_job_url='https://github.com/acme/app/actions/runs/8/job/800',
        )
    ])
    resp = mod.lambda_handler(event, None)
    body = json.loads(resp['body'])
    assert len(body['queued']) == 1
    assert body['skipped'] == []
