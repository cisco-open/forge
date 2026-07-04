"""Guard-path MiniStack smoke tests for first-party Lambda handlers.

These tests deploy self-contained handlers and invoke safe no-op/reject paths.
They prove the real handler files import and execute under the Lambda emulator
without making CI depend on live GitHub, Webex, Splunk, or cross-account AWS.
"""

from __future__ import annotations

import io
import json
import time
import zipfile
from pathlib import Path

import pytest
from botocore.exceptions import ClientError

pytestmark = pytest.mark.lambda_exec

_REPO_ROOT = Path(__file__).resolve().parents[3]


def _zip_handler(source: Path) -> bytes:
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, 'w') as z:
        z.writestr('handler.py', source.read_text())
    return buf.getvalue()


def _wait_until_active(lam, function_name: str):
    for _ in range(30):
        state = lam.get_function(FunctionName=function_name)[
            'Configuration'].get('State')
        if state in (None, 'Active'):
            return
        time.sleep(1)
    raise AssertionError(f'Lambda {function_name} did not become active')


def _deploy_handler(client, *, function_name: str, source: Path, env: dict[str, str]):
    assert source.exists(), f'handler not found: {source}'
    lam = client('lambda')
    try:
        lam.create_function(
            FunctionName=function_name,
            Runtime='python3.12',
            Role='arn:aws:iam::000000000000:role/forge-smoke-lambda',
            Handler='handler.lambda_handler',
            Code={'ZipFile': _zip_handler(source)},
            Timeout=30,
            Environment={'Variables': env},
        )
    except ClientError as e:
        if e.response['Error']['Code'] != 'ResourceConflictException':
            raise
        lam.update_function_code(
            FunctionName=function_name,
            ZipFile=_zip_handler(source),
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
]


@pytest.mark.parametrize('case', CASES, ids=[case['id'] for case in CASES])
def test_lambda_handler_guard_path_executes_in_ministack(client, case):
    lam = _deploy_handler(
        client,
        function_name=case['function_name'],
        source=_REPO_ROOT / case['source'],
        env=case['env'],
    )

    resp, payload = _invoke(lam, case['function_name'], case['event'])
    assert 'FunctionError' not in resp

    expected = case['expected']
    if isinstance(expected, dict) and 'body_json' in expected:
        assert payload['statusCode'] == expected['statusCode']
        assert json.loads(payload['body']) == expected['body_json']
        return

    assert payload == expected
