"""Guard-path MiniStack smoke tests for first-party Lambda handlers.

These tests deploy self-contained handlers and invoke safe no-op/reject paths.
They prove the real handler files import and execute under the Lambda emulator
without making CI depend on live GitHub, Webex, Splunk, or cross-account AWS.
"""

from __future__ import annotations

import base64
import io
import json
import time
import zipfile
from pathlib import Path

import pytest
from botocore.exceptions import ClientError

pytestmark = pytest.mark.lambda_exec

_REPO_ROOT = Path(__file__).resolve().parents[3]


def _zip_handler(
    source: Path,
    extra_sources: dict[str, Path] | None = None,
) -> bytes:
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, 'w') as z:
        z.writestr('handler.py', source.read_text())
        for archive_name, extra_source in (extra_sources or {}).items():
            z.writestr(archive_name, extra_source.read_text())
    return buf.getvalue()


def _wait_until_active(lam, function_name: str):
    for _ in range(30):
        state = lam.get_function(FunctionName=function_name)[
            'Configuration'].get('State')
        if state in (None, 'Active'):
            return
        time.sleep(1)
    raise AssertionError(f'Lambda {function_name} did not become active')


def _deploy_handler(
    client,
    *,
    function_name: str,
    source: Path,
    env: dict[str, str],
    handler: str = 'handler.lambda_handler',
    extra_sources: dict[str, Path] | None = None,
):
    assert source.exists(), f'handler not found: {source}'
    for extra_source in (extra_sources or {}).values():
        assert extra_source.exists(), (
            f'handler dependency not found: {extra_source}'
        )
    lam = client('lambda')
    try:
        lam.create_function(
            FunctionName=function_name,
            Runtime='python3.12',
            Role='arn:aws:iam::000000000000:role/forge-smoke-lambda',
            Handler=handler,
            Code={'ZipFile': _zip_handler(source, extra_sources)},
            Timeout=30,
            Environment={'Variables': env},
        )
    except ClientError as e:
        if e.response['Error']['Code'] != 'ResourceConflictException':
            raise
        lam.update_function_code(
            FunctionName=function_name,
            ZipFile=_zip_handler(source, extra_sources),
        )
        _wait_until_active(lam, function_name)
        lam.update_function_configuration(
            FunctionName=function_name,
            Environment={'Variables': env},
        )

    _wait_until_active(lam, function_name)
    return lam


def _invoke(lam, function_name: str, event: dict):
    resp = lam.invoke(
        FunctionName=function_name,
        Payload=json.dumps(event).encode(),
    )
    assert resp['StatusCode'] == 200
    payload = json.loads(resp['Payload'].read())
    return resp, payload


def _unique_name(prefix: str) -> str:
    return f'{prefix}-{int(time.time() * 1000)}'


def _wait_for_stream_active(kinesis, stream_name: str):
    for _ in range(30):
        status = kinesis.describe_stream(StreamName=stream_name)[
            'StreamDescription'
        ]['StreamStatus']
        if status == 'ACTIVE':
            return
        time.sleep(1)
    raise AssertionError(f'Kinesis stream {stream_name} did not become active')


def _kinesis_records(kinesis, stream_name: str) -> list[dict]:
    stream = kinesis.describe_stream(StreamName=stream_name)[
        'StreamDescription']
    shard_id = stream['Shards'][0]['ShardId']
    iterator = kinesis.get_shard_iterator(
        StreamName=stream_name,
        ShardId=shard_id,
        ShardIteratorType='TRIM_HORIZON',
    )['ShardIterator']

    for _ in range(10):
        response = kinesis.get_records(ShardIterator=iterator, Limit=10)
        records = response.get('Records', [])
        if records:
            return records
        iterator = response.get('NextShardIterator', iterator)
        time.sleep(1)

    return []


def _record_data(record: dict) -> bytes:
    data = record['Data']
    if isinstance(data, bytes):
        return data
    return base64.b64decode(data)


CASES = [
    {
        'id': 'webex-webhook-relay-no-workflow-run',
        'function_name': 'forge-smoke-webex-webhook-relay',
        'source': Path(
            'modules/integrations/github_webhook_relay_destination_receivers/'
            'webex_webhook_relay/lambda/handler.py'
        ),
        'env': {'LOG_LEVEL': 'INFO'},
        'event': {},
        'expected': {'statusCode': 200, 'body': 'No workflow_run'},
    },
    {
        'id': 'job-log-dispatcher-ignores-non-workflow-job',
        'function_name': 'forge-smoke-job-log-dispatcher',
        'source': Path(
            'modules/platform/forge_runners/github_actions_job_logs/lambda/'
            'job_log_dispatcher/job_log_dispatcher.py'
        ),
        'env': {
            'LOG_LEVEL': 'INFO',
            'REPO_TENANT_JSON': '{}',
            'QUEUE_URL': 'https://sqs.us-east-1.amazonaws.com/000000000000/unused',
        },
        'event': {'detail-type': 'not_workflow_job'},
        'expected': {
            'statusCode': 200,
            'body_json': {'message': 'ignored event'},
        },
    },
    {
        'id': 'redrive-deadletter-empty-map',
        'function_name': 'forge-smoke-redrive-deadletter',
        'source': Path(
            'modules/platform/forge_runners/redrive_deadletter/lambda/'
            'redrive_deadletter.py'
        ),
        'env': {'LOG_LEVEL': 'INFO', 'SQS_MAP': ''},
        'event': {},
        'expected': {
            'status': 'noop',
            'message': 'SQS_MAP is empty',
            'results': [],
        },
    },
    {
        'id': 'ec2-update-runner-tags-ignores-non-workflow-job',
        'function_name': 'forge-smoke-ec2-update-runner-tags',
        'source': Path(
            'modules/platform/ec2_deployment/ec2_update_runner_tags/lambda/'
            'ec2_update_runner_tags.py'
        ),
        'env': {'LOG_LEVEL': 'INFO'},
        'event': {'detail-type': 'not_workflow_job'},
        'expected': {
            'statusCode': 200,
            'body_json': {'message': 'ignored event'},
        },
    },
    {
        'id': 'ec2-update-runner-ssm-ami-empty-map',
        'function_name': 'forge-smoke-ec2-update-runner-ssm-ami',
        'source': Path(
            'modules/platform/ec2_deployment/ec2_update_runner_ssm_ami/lambda/'
            'ec2_update_runner_ssm_ami.py'
        ),
        'env': {'LOG_LEVEL': 'INFO', 'RUNNER_AMI_MAP': '{}'},
        'event': {},
        'expected': {
            'statusCode': 200,
            'body_json': {'message': 'AMI SSM update process completed'},
        },
    },
    {
        'id': 'splunk-stuck-dispatcher-rejects-bad-token',
        'function_name': 'forge-smoke-splunk-stuck-dispatcher',
        'source': Path(
            'modules/integrations/splunk_stuck_workflow_job_dispatcher/lambda/'
            'handler.py'
        ),
        'env': {
            'LOG_LEVEL': 'INFO',
            'WEBHOOK_TOKEN': 'expected-token',
            'DEDUPE_TABLE': 'unused',
        },
        'event': {
            'requestContext': {'http': {'method': 'POST'}},
            'pathParameters': {'token': 'wrong-token'},
            'body': '',
        },
        'expected': {
            'statusCode': 403,
            'body_json': {'message': 'Invalid webhook token'},
        },
    },
    {
        'id': 'splunk-stuck-worker-empty-stream',
        'function_name': 'forge-smoke-splunk-stuck-worker',
        'source': Path(
            'modules/integrations/splunk_stuck_workflow_job_dispatcher/lambda/'
            'worker.py'
        ),
        'env': {'LOG_LEVEL': 'INFO', 'DEDUPE_TABLE': 'unused'},
        'event': {'Records': []},
        'expected': {'failures': []},
    },
    {
        'id': 'sec-meta-ec2-tags-ignores-non-createtags',
        'function_name': 'forge-smoke-sec-meta-ec2-tags',
        'source': Path(
            'modules/integrations/splunk_cloud_data_manager/'
            'sec_meta_ec2_tags/lambda/sec_meta_ec2_tags.py'
        ),
        'env': {
            'LOG_LEVEL': 'INFO',
            'SPLUNK_DATA_MANAGER_INPUT_ID': 'unused',
            'SPLUNK_HEC_HOST': 'http://127.0.0.1:9',
            'SPLUNK_HEC_TOKEN': 'unused',
        },
        'event': {'detail': {'eventName': 'DescribeInstances'}},
        'expected': None,
    },
    {
        'id': 'trust-preparer-rejects-empty-role-config',
        'function_name': 'forge-smoke-trust-preparer',
        'source': Path(
            'modules/platform/forge_runners/forge_trust_validator/lambda/'
            'trust_preparer.py'
        ),
        'handler': 'handler.prepare_handler',
        'extra_sources': {
            'trust_common.py': Path(
                'modules/platform/forge_runners/forge_trust_validator/lambda/'
                'trust_common.py'
            ),
        },
        'env': {
            'LOG_LEVEL': 'INFO',
            'FORGE_IAM_ROLES': '',
            'TENANT_IAM_ROLES': '',
            'VALIDATOR_LAMBDA_ROLE_ARN': (
                'arn:aws:iam::000000000000:role/forge-smoke-validator'
            ),
            'VALIDATION_QUEUE_URL': (
                'https://sqs.us-east-1.amazonaws.com/000000000000/unused'
            ),
            'VALIDATION_DELAY_SECONDS': '0',
        },
        'event': {},
        'expected_function_error': 'Unhandled',
        'expected_error_message': 'Missing forge_role_arns or tenant_role_arns',
    },
    {
        'id': 'trust-validator-rejects-non-sqs-event',
        'function_name': 'forge-smoke-trust-validator',
        'source': Path(
            'modules/platform/forge_runners/forge_trust_validator/lambda/'
            'trust_validator.py'
        ),
        'handler': 'handler.validate_handler',
        'extra_sources': {
            'trust_common.py': Path(
                'modules/platform/forge_runners/forge_trust_validator/lambda/'
                'trust_common.py'
            ),
        },
        'env': {'LOG_LEVEL': 'INFO'},
        'event': {},
        'expected_function_error': 'Unhandled',
        'expected_error_message': (
            'Validator Lambda only accepts SQS validation events'
        ),
    },
]


@pytest.mark.parametrize('case', CASES, ids=[case['id'] for case in CASES])
def test_lambda_handler_guard_path_executes_in_ministack(client, case):
    lam = _deploy_handler(
        client,
        function_name=case['function_name'],
        source=_REPO_ROOT / case['source'],
        env=case['env'],
        handler=case.get('handler', 'handler.lambda_handler'),
        extra_sources={
            name: _REPO_ROOT / source
            for name, source in case.get('extra_sources', {}).items()
        },
    )

    resp, payload = _invoke(lam, case['function_name'], case['event'])
    if 'expected_function_error' in case:
        assert resp.get('FunctionError') == case['expected_function_error']
        assert case['expected_error_message'] in payload['errorMessage']
        return

    assert 'FunctionError' not in resp

    expected = case['expected']
    if isinstance(expected, dict) and 'body_json' in expected:
        assert payload['statusCode'] == expected['statusCode']
        assert json.loads(payload['body']) == expected['body_json']
        return

    assert payload == expected


def test_job_log_dispatcher_enqueues_workflow_job_event(client):
    sqs = client('sqs')
    queue_url = sqs.create_queue(
        QueueName=_unique_name('forge-smoke-job-log-dispatcher')
    )['QueueUrl']
    lam = _deploy_handler(
        client,
        function_name='forge-smoke-job-log-dispatcher',
        source=_REPO_ROOT / (
            'modules/platform/forge_runners/github_actions_job_logs/lambda/'
            'job_log_dispatcher/job_log_dispatcher.py'
        ),
        env={
            'LOG_LEVEL': 'INFO',
            'REPO_TENANT_JSON': '{}',
            'QUEUE_URL': queue_url,
        },
    )
    event = {
        'detail-type': 'workflow_job',
        'detail': {
            'action': 'completed',
            'repository': {'full_name': 'cisco-open/forge'},
            'workflow_job': {
                'id': 12345,
                'run_id': 67890,
                'workflow_name': 'MiniStack Smoke',
                'run_attempt': 2,
                'name': 'MiniStack smoke + real-handler exec',
                'status': 'completed',
                'conclusion': 'success',
                'head_branch': 'main',
                'head_sha': 'abcdef1234567890',
                'labels': ['self-hosted', 'forge'],
            },
        },
    }

    resp, payload = _invoke(lam, 'forge-smoke-job-log-dispatcher', event)
    assert 'FunctionError' not in resp
    assert payload == {'enqueued': True}

    messages = sqs.receive_message(
        QueueUrl=queue_url,
        MaxNumberOfMessages=1,
        WaitTimeSeconds=2,
    ).get('Messages', [])
    assert len(messages) == 1
    assert json.loads(messages[0]['Body']) == event


def test_splunk_s3_runner_logs_ships_log_lines_to_kinesis(client):
    s3 = client('s3')
    kinesis = client('kinesis')
    bucket = _unique_name('forge-smoke-runner-logs')
    stream_name = _unique_name('forge-smoke-runner-logs')
    log_key = 'runs/123/job.log'
    sidecar_key = 'runs/123/job.fields'

    s3.create_bucket(Bucket=bucket)
    s3.put_object(
        Bucket=bucket,
        Key=log_key,
        Body=(
            b'2026-07-04T00:00:00.000Z first line\n'
            b'second line without timestamp\n'
        ),
        Tagging='runner_name=i-1234567890abcdef0',
    )
    s3.put_object(
        Bucket=bucket,
        Key=sidecar_key,
        Body=json.dumps({
            'fields': {
                'repository': 'cisco-open/forge',
                'run_id': 67890,
                'workflow': 'MiniStack Smoke',
            }
        }).encode(),
    )
    kinesis.create_stream(StreamName=stream_name, ShardCount=1)
    _wait_for_stream_active(kinesis, stream_name)

    lam = _deploy_handler(
        client,
        function_name='forge-smoke-splunk-s3-runner-logs',
        source=_REPO_ROOT / (
            'modules/integrations/splunk_cloud_s3_runner_logs/lambda/'
            'splunk_s3_runner_logs.py'
        ),
        env={
            'LOG_LEVEL': 'INFO',
            'KINESIS_STREAM_NAME': stream_name,
            'INDEX': 'forge',
            'SOURCETYPE': 'forgecicd:runner-logs:logs',
        },
    )
    event = {
        'Records': [
            {
                'body': json.dumps({
                    'Records': [
                        {
                            's3': {
                                'bucket': {'name': bucket},
                                'object': {'key': log_key},
                            }
                        }
                    ]
                })
            }
        ]
    }

    resp, payload = _invoke(lam, 'forge-smoke-splunk-s3-runner-logs', event)
    assert 'FunctionError' not in resp
    assert payload['statusCode'] == 200
    assert json.loads(payload['body']) == {'lines': 2}

    records = _kinesis_records(kinesis, stream_name)
    assert len(records) == 2
    wrapped = [json.loads(_record_data(record).decode()) for record in records]
    assert [record['event'] for record in wrapped] == [
        '2026-07-04T00:00:00.000Z first line',
        'second line without timestamp',
    ]
    assert wrapped[0]['source'] == f'{bucket}:{log_key}'
    assert wrapped[0]['fields']['repository'] == 'cisco-open/forge'
    assert wrapped[0]['fields']['run_id'] == 67890
    assert wrapped[0]['fields']['runner_name'] == 'i-1234567890abcdef0'
