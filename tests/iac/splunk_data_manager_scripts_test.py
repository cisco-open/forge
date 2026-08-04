"""Hermetic tests for the Splunk Data Manager shell helpers."""

from __future__ import annotations

import copy
import json
import os
import subprocess
from pathlib import Path
from urllib.parse import urlparse

import pytest

pytestmark = pytest.mark.contract

REPO_ROOT = Path(__file__).resolve().parents[2]
HELPER = REPO_ROOT / (
    'modules/integrations/splunk_cloud_data_manager/data_input/'
    'scripts/splunk_integration_helpers.sh'
)
CREATE_SCRIPT = HELPER.parent / 'create_splunk_integration.sh'
AWS_ACCOUNT_ID = '166060576821'


def sqs_url(queue_name: str, region: str = 'us-east-1') -> str:
    return (
        f'https://sqs.{region}.amazonaws.com/'
        f'{AWS_ACCOUNT_ID}/{queue_name}'
    )


def s3_status_key(queue_url: str) -> str:
    parsed = urlparse(queue_url)
    region = parsed.hostname.split('.')[1]
    queue_name = parsed.path.rsplit('/', maxsplit=1)[-1]
    return f'scc_{region}_{queue_name}_input-id'


def s3_request(
    *,
    queue_urls: list[str] | None = None,
    s3_bucket_patterns: list[str] | None = None,
    kms_key_arns: list[str] | None = None,
) -> dict[str, object]:
    if queue_urls is None:
        queue_urls = [sqs_url('queue-0')]
    if s3_bucket_patterns is None:
        s3_bucket_patterns = ['forge-logs-*']
    if kms_key_arns is None:
        kms_key_arns = []

    return {
        'name': 'forge-s3-logs',
        'type': 'AWS',
        'destination': {
            'type': 'index',
            'details': {'s3-custom-logs': 'forge-index'},
        },
        'mode': 'Complete',
        'details': {
            'type': 'SingleAccount',
            'iamRegion': 'us-east-1',
            'datasetInfo': {
                's3-custom-logs': {
                    'sqsUrls': [
                        {'sqsUrl': queue_url} for queue_url in queue_urls
                    ],
                    'sourceType': 'forgecicd:runner-logs:s3',
                },
            },
            'dataAccounts': ['166060576821'],
            's3BucketPatterns': s3_bucket_patterns,
            'kmsKeyArns': kms_key_arns,
        },
    }


def s3_response(
    state: str,
    *,
    include_stack_details: bool = True,
    queue_count: int = 1,
    status_count: int | None = None,
    request: dict[str, object] | None = None,
    version: int = 1,
    last_update_time: str = '2026-08-04 14:17:37+00:00',
    status_queue_urls: list[str] | None = None,
) -> dict[str, object]:
    if request is None:
        request = s3_request(
            queue_urls=[
                sqs_url(f'queue-{index}')
                for index in range(queue_count)
            ]
        )

    configured_queue_urls = [
        entry['sqsUrl']
        for entry in request['details']['datasetInfo']['s3-custom-logs'][
            'sqsUrls'
        ]
    ]
    queue_count = len(configured_queue_urls)

    if status_count is None:
        status_count = queue_count
    if status_queue_urls is None:
        status_queue_urls = configured_queue_urls[:status_count]

    response = copy.deepcopy(request)
    details = response['details']
    if include_stack_details:
        details.update(
            {
                'stackName': 'SplunkDMSqsS3-input-id',
                'version': version,
            }
        )

    response['dataSourcesStatus'] = {
        s3_status_key(queue_url): {
            'status': {
                'state': state,
                'message': '',
            }
        }
        for queue_url in status_queue_urls
    }
    response['lastUpdateTime'] = last_update_time
    response['id'] = 'input-id'
    return response


def run_wait(
    tmp_path: Path,
    initial: dict[str, object],
    refreshed: dict[str, object],
    *,
    max_attempts: int = 2,
    request: dict[str, object] | None = None,
    expected_version: str = '',
    expected_update_time: str = '',
) -> tuple[subprocess.CompletedProcess[str], Path, Path]:
    input_path = tmp_path / 'input.json'
    refreshed_path = tmp_path / 'refreshed.json'
    log_path = tmp_path / 'wait.log'
    request_path = tmp_path / 'request.json'
    input_path.write_text(json.dumps(initial), encoding='utf-8')
    refreshed_path.write_text(json.dumps(refreshed), encoding='utf-8')
    if request is not None:
        request_path.write_text(json.dumps(request), encoding='utf-8')

    env = os.environ.copy()
    env.update(
        {
            'HELPER': str(HELPER),
            'INPUT': str(input_path),
            'REFRESHED': str(refreshed_path),
            'WAIT_LOG': str(log_path),
            'MAX_ATTEMPTS': str(max_attempts),
            'REQUEST': str(request_path) if request is not None else '',
            'EXPECTED_VERSION': expected_version,
            'EXPECTED_UPDATE_TIME': expected_update_time,
        }
    )
    script = '''
. "$HELPER"
fetch_input() { cp "$REFRESHED" "$INPUT"; }
splunk_wait_for_s3_input \
    "$INPUT" fetch_input "$WAIT_LOG" "$MAX_ATTEMPTS" 0 \
    "$REQUEST" "$EXPECTED_VERSION" "$EXPECTED_UPDATE_TIME"
'''
    result = subprocess.run(
        ['bash', '-c', script],
        check=False,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    return result, input_path, log_path


def test_s3_wait_retries_an_in_progress_response(tmp_path: Path) -> None:
    result, input_path, log_path = run_wait(
        tmp_path,
        s3_response(
            'CreateDataSourceInProgress',
            include_stack_details=False,
        ),
        s3_response('CreateDataSourceSuccess'),
    )

    assert result.returncode == 0, result.stderr
    input_details = json.loads(
        input_path.read_text(encoding='utf-8')
    )['details']
    assert input_details['stackName'] == 'SplunkDMSqsS3-input-id'
    assert not log_path.exists()


def test_s3_wait_fails_immediately_on_provisioning_error(
    tmp_path: Path,
) -> None:
    response = s3_response(
        'CreateDataSourceFailure',
        include_stack_details=False,
    )
    result, _, log_path = run_wait(tmp_path, response, response)

    assert result.returncode == 1
    assert 'provisioning failed' in log_path.read_text(encoding='utf-8')


def test_s3_wait_requires_success_for_every_configured_queue(
    tmp_path: Path,
) -> None:
    result, input_path, _ = run_wait(
        tmp_path,
        s3_response('CreateDataSourceSuccess', queue_count=2, status_count=1),
        s3_response('CreateDataSourceSuccess', queue_count=2),
    )

    assert result.returncode == 0, result.stderr
    response = json.loads(input_path.read_text(encoding='utf-8'))
    assert len(response['dataSourcesStatus']) == 2


def test_s3_wait_rejects_stale_success_for_a_changed_request(
    tmp_path: Path,
) -> None:
    old_request = s3_request(
        queue_urls=[sqs_url('old-queue')],
        s3_bucket_patterns=['old-bucket-*'],
    )
    expected_request = s3_request(
        queue_urls=[sqs_url('new-queue')],
        s3_bucket_patterns=['new-bucket-*'],
    )
    result, input_path, _ = run_wait(
        tmp_path,
        s3_response('CreateDataSourceSuccess', request=old_request),
        s3_response('CreateDataSourceSuccess', request=expected_request),
        request=expected_request,
    )

    assert result.returncode == 0, result.stderr
    response = json.loads(input_path.read_text(encoding='utf-8'))
    assert response['details']['s3BucketPatterns'] == [
        'new-bucket-*'
    ]


def test_s3_wait_rejects_a_replaced_queues_stale_success(
    tmp_path: Path,
) -> None:
    old_queue_url = sqs_url('logs_old', region='eu-west-1')
    new_queue_url = sqs_url('logs', region='eu-west-1')
    request = s3_request(queue_urls=[new_queue_url])
    result, input_path, _ = run_wait(
        tmp_path,
        s3_response(
            'CreateDataSourceSuccess',
            request=request,
            status_queue_urls=[old_queue_url],
        ),
        s3_response('CreateDataSourceSuccess', request=request),
        request=request,
        expected_version='1',
        expected_update_time='2026-08-04 14:17:37+00:00',
    )

    assert result.returncode == 0, result.stderr
    response = json.loads(input_path.read_text(encoding='utf-8'))
    assert list(response['dataSourcesStatus']) == [
        s3_status_key(new_queue_url)
    ]


def test_s3_wait_rejects_success_from_an_older_version(
    tmp_path: Path,
) -> None:
    request = s3_request()
    result, input_path, _ = run_wait(
        tmp_path,
        s3_response('CreateDataSourceSuccess', request=request, version=1),
        s3_response('CreateDataSourceSuccess', request=request, version=2),
        request=request,
        expected_version='2',
    )

    assert result.returncode == 0, result.stderr
    response = json.loads(input_path.read_text(encoding='utf-8'))
    assert response['details']['version'] == 2


def test_s3_wait_rejects_success_from_an_older_update(
    tmp_path: Path,
) -> None:
    request = s3_request()
    expected_update_time = '2026-08-04 14:18:00+00:00'
    result, input_path, _ = run_wait(
        tmp_path,
        s3_response(
            'CreateDataSourceSuccess',
            request=request,
            last_update_time='2026-08-04 14:17:00+00:00',
        ),
        s3_response(
            'CreateDataSourceSuccess',
            request=request,
            last_update_time=expected_update_time,
        ),
        request=request,
        expected_version='1',
        expected_update_time=expected_update_time,
    )

    assert result.returncode == 0, result.stderr
    response = json.loads(input_path.read_text(encoding='utf-8'))
    assert response['lastUpdateTime'] == expected_update_time


def test_s3_wait_retries_a_transient_initial_fetch(tmp_path: Path) -> None:
    input_path = tmp_path / 'input.json'
    refreshed_path = tmp_path / 'refreshed.json'
    log_path = tmp_path / 'wait.log'
    attempts_path = tmp_path / 'attempts.txt'
    refreshed_path.write_text(
        json.dumps(s3_response('CreateDataSourceSuccess')),
        encoding='utf-8',
    )
    env = {
        **os.environ,
        'HELPER': str(HELPER),
        'INPUT': str(input_path),
        'REFRESHED': str(refreshed_path),
        'WAIT_LOG': str(log_path),
        'ATTEMPTS': str(attempts_path),
    }
    script = '''
. "$HELPER"
fetch_attempts=0
fetch_input() {
    fetch_attempts=$((fetch_attempts + 1))
    if [ "$fetch_attempts" -eq 1 ]; then
        return 1
    fi
    cp "$REFRESHED" "$INPUT"
}
splunk_wait_for_s3_input "$INPUT" fetch_input "$WAIT_LOG" 2 0
wait_status=$?
printf '%s' "$fetch_attempts" >"$ATTEMPTS"
exit "$wait_status"
'''
    result = subprocess.run(
        ['bash', '-c', script],
        check=False,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )

    assert result.returncode == 0, result.stderr
    assert attempts_path.read_text(encoding='utf-8') == '2'


def test_s3_wait_does_not_retry_a_non_retryable_fetch(
    tmp_path: Path,
) -> None:
    input_path = tmp_path / 'input.json'
    log_path = tmp_path / 'wait.log'
    attempts_path = tmp_path / 'attempts.txt'
    env = {
        **os.environ,
        'HELPER': str(HELPER),
        'INPUT': str(input_path),
        'WAIT_LOG': str(log_path),
        'ATTEMPTS': str(attempts_path),
    }
    script = '''
. "$HELPER"
fetch_attempts=0
fetch_input() {
    fetch_attempts=$((fetch_attempts + 1))
    return 2
}
splunk_wait_for_s3_input "$INPUT" fetch_input "$WAIT_LOG" 3 0
wait_status=$?
printf '%s' "$fetch_attempts" >"$ATTEMPTS"
exit "$wait_status"
'''
    result = subprocess.run(
        ['bash', '-c', script],
        check=False,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )

    assert result.returncode == 1
    assert attempts_path.read_text(encoding='utf-8') == '1'
    assert 'non-retryable HTTP response' in log_path.read_text(
        encoding='utf-8'
    )


def test_create_input_put_failure_is_guarded() -> None:
    script = CREATE_SCRIPT.read_text(encoding='utf-8')

    guarded_put = (
        'if ! curl --fail --silent --show-error '
        '"${splunk_cloud}/en-GB/splunkd/__raw/servicesNS/nobody/'
        'data_manager/cloudinput/inputs/${splunk_input_uuid}"'
    )
    assert guarded_put in script
    assert '--data-raw "${splunk_cloud_input_json}"' in script
    assert 'expected_version=$(jq -r' in script
    assert 'expected_update_time=$(jq -r' in script
    assert '404 | 409 | 429 | 5?? | 000 | "")' in script


def test_s3_wait_stops_after_the_bounded_attempts(tmp_path: Path) -> None:
    response = s3_response('CreateDataSourceInProgress')
    result, _, log_path = run_wait(
        tmp_path,
        response,
        response,
        max_attempts=2,
    )

    assert result.returncode == 1
    assert 'not ready after 2 attempts' in log_path.read_text(
        encoding='utf-8'
    )


def test_wait_ignores_push_based_inputs(tmp_path: Path) -> None:
    input_path = tmp_path / 'input.json'
    input_path.write_text(
        json.dumps({'details': {'datasetInfo': {'cwl-lambda': {}}}}),
        encoding='utf-8',
    )
    log_path = tmp_path / 'wait.log'
    env = os.environ.copy()
    env.update(
        {
            'HELPER': str(HELPER),
            'INPUT': str(input_path),
            'WAIT_LOG': str(log_path),
        }
    )
    result = subprocess.run(
        [
            'bash',
            '-c',
            '. "$HELPER"; fetch_input() { return 99; }; '
            'splunk_wait_for_s3_input "$INPUT" fetch_input "$WAIT_LOG" 1 0',
        ],
        check=False,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )

    assert result.returncode == 0, result.stderr
    assert not log_path.exists()


def test_wait_rejects_an_invalid_input_response(tmp_path: Path) -> None:
    response = {'message': 'input is not ready'}
    result, _, log_path = run_wait(tmp_path, response, response)

    assert result.returncode == 1
    assert 'invalid data input response' in log_path.read_text(
        encoding='utf-8'
    )


@pytest.mark.parametrize(
    ('template', 'expected_returncode'),
    [
        ({'Resources': {'Role': {'Type': 'AWS::IAM::Role'}}}, 0),
        ({'message': 'template is not ready'}, 1),
        ({'Resources': {}}, 1),
    ],
)
def test_cloudformation_template_validation(
    tmp_path: Path,
    template: dict[str, object],
    expected_returncode: int,
) -> None:
    template_path = tmp_path / 'template.json'
    template_path.write_text(json.dumps(template), encoding='utf-8')
    result = subprocess.run(
        [
            'bash',
            '-c',
            '. "$HELPER"; splunk_validate_cloudformation_template "$TEMPLATE"',
        ],
        check=False,
        env={
            **os.environ,
            'HELPER': str(HELPER),
            'TEMPLATE': str(template_path),
        },
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )

    assert result.returncode == expected_returncode
