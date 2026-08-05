"""Unit tests for the Splunk Data Manager Python lifecycle command."""

from __future__ import annotations

import copy
import hashlib
import http.cookiejar
import importlib
import io
import json
import subprocess
import sys
from collections import deque
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Thread
from urllib.parse import parse_qs

import pytest

pytestmark = pytest.mark.contract

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT_PATH = REPO_ROOT / (
    'modules/integrations/splunk_cloud_data_manager/data_input/'
    'scripts/splunk_integration.py'
)
sys.path.insert(0, str(SCRIPT_PATH.parent))
splunk_integration = importlib.import_module('splunk_integration')

PUSH_DATASET_CATEGORIES = (
    ('cwl-api-gateway', 'aws-cwl'),
    ('cwl-cloudhsm', 'aws-cwl'),
    ('cwl-documentDB', 'aws-cwl'),
    ('cwl-eks', 'aws-cwl'),
    ('cwl-lambda', 'aws-cwl'),
    ('cwl-rds', 'aws-cwl'),
    ('cwl-custom-logs', 'cwl-custom-logs'),
    ('cwl-vpc-flow-logs', 'cwl-vpc-flow-logs'),
    ('cloudtrail', 'cloudtrail'),
    ('securityhub', 'securityhub'),
    ('guardduty', 'guardduty'),
    ('iam-aa', 'iam-aa'),
    ('iam-cr', 'iam-cr'),
    ('metadata', 'metadata'),
)

AWS_ACCOUNT_ID = '123456789012'
S3_DATASETS = (
    's3-custom-logs',
    'ct-logs',
    's3-access-logs',
    'elb-access-logs',
    'cf-access-logs',
)

CLEANUP_CATEGORIES = (
    'aws-cwl',
    'cwl-custom-logs',
    'cwl-vpc-flow-logs',
    'cloudtrail',
    'securityhub',
    'guardduty',
    'iam-aa',
    'iam-cr',
    'metadata',
)

VALID_TEMPLATE = b'{"Resources":{"Role":{"Type":"AWS::IAM::Role"}}}'


def push_request(
    datasets: tuple[str, ...] = ('cloudtrail',),
) -> dict[str, object]:
    return {
        'name': 'forge-push-logs',
        'type': 'AWS',
        'destination': {
            'type': 'index',
            'details': {
                dataset: 'forge-index'
                for dataset in datasets
            },
        },
        'mode': 'Complete',
        'details': {
            'type': 'SingleAccount',
            'datasetInfo': {
                dataset: {}
                for dataset in datasets
            },
            'dataAccounts': ['123456789012'],
        },
    }


def push_response(
    datasets: tuple[str, ...] = ('cloudtrail',),
    *,
    version: int = 7,
) -> dict[str, object]:
    document = copy.deepcopy(push_request(datasets))
    document.update(
        {
            '_key': 'input-id',
            '_user': 'nobody',
            'createTime': '2026-08-05 10:00:00+00:00',
            'id': 'input-id',
            'lastUpdateTime': '2026-08-05 10:01:00+00:00',
            'schemaVersion': '3.0',
        }
    )
    document['details'].update(
        {
            'stackName': 'SplunkDMDataIngest-input-id',
            'version': version,
            'resources': {'us-east-1': []},
            'resourceTags': {'Product': 'Forge'},
        }
    )
    return document


def sqs_url(queue_name: str, region: str = 'us-east-1') -> str:
    return (
        f'https://sqs.{region}.amazonaws.com/'
        f'{AWS_ACCOUNT_ID}/{queue_name}'
    )


def s3_status_key(queue_url: str) -> str:
    host = queue_url.split('/')[2]
    region = host.split('.')[1]
    queue_name = queue_url.rsplit('/', maxsplit=1)[-1]
    return f'scc_{region}_{queue_name}_input-id'


def s3_request(
    *,
    dataset: str = 's3-custom-logs',
    queue_urls: list[str] | None = None,
    s3_bucket_patterns: list[str] | None = None,
    kms_key_arns: list[str] | None = None,
) -> dict[str, object]:
    if queue_urls is None:
        queue_urls = [sqs_url('forge-s3-logs')]
    if s3_bucket_patterns is None:
        s3_bucket_patterns = ['forge-logs-*']
    if kms_key_arns is None:
        kms_key_arns = []

    dataset_info: dict[str, object] = {
        'sqsUrls': [
            {'sqsUrl': queue_url}
            for queue_url in queue_urls
        ],
    }
    if dataset == 's3-custom-logs':
        dataset_info['sourceType'] = 'forge:s3'

    return {
        'name': 'forge-s3-logs',
        'type': 'AWS',
        'destination': {
            'type': 'index',
            'details': {dataset: 'forge-index'},
        },
        'mode': 'Complete',
        'details': {
            'type': 'SingleAccount',
            'iamRegion': 'us-east-1',
            'datasetInfo': {dataset: dataset_info},
            'dataAccounts': [AWS_ACCOUNT_ID],
            's3BucketPatterns': s3_bucket_patterns,
            'kmsKeyArns': kms_key_arns,
        },
    }


def s3_response(
    state: str = 'CreateDataSourceSuccess',
    *,
    include_stack_details: bool = True,
    queue_count: int = 1,
    status_count: int | None = None,
    request: dict[str, object] | None = None,
    version: int = 1,
    last_update_time: str = '2026-08-05 10:01:00+00:00',
    status_queue_urls: list[str] | None = None,
) -> dict[str, object]:
    if request is None:
        request = s3_request(
            queue_urls=[
                sqs_url(f'queue-{index}')
                for index in range(queue_count)
            ]
        )

    dataset = next(iter(request['details']['datasetInfo']))
    configured_urls = [
        entry['sqsUrl']
        for entry in request['details']['datasetInfo'][dataset]['sqsUrls']
    ]
    if status_count is None:
        status_count = len(configured_urls)
    if status_queue_urls is None:
        status_queue_urls = configured_urls[:status_count]

    document = copy.deepcopy(request)
    document.update(
        {
            '_key': 'input-id',
            '_user': 'nobody',
            'createTime': '2026-08-05 10:00:00+00:00',
            'id': 'input-id',
            'lastUpdateTime': last_update_time,
            'schemaVersion': '3.0',
        }
    )
    if include_stack_details:
        document['details'].update(
            {
                'stackName': 'SplunkDMSqsS3-input-id',
                'version': version,
                'resources': {'us-east-1': []},
                'resourceTags': {'Product': 'Forge'},
            }
        )
    document['dataSourcesStatus'] = {
        s3_status_key(queue_url): {
            'status': {'state': state, 'message': ''}
        }
        for queue_url in status_queue_urls
    }
    return document


def fetch_sequence(*items):
    remaining = deque(items)
    last = items[-1]

    def fetch():
        nonlocal last
        if remaining:
            last = remaining.popleft()
        if isinstance(last, BaseException):
            raise last
        return copy.deepcopy(last)

    return fetch


class FakeClient:
    def __init__(
        self,
        *,
        input_responses=(),
        template: bytes | BaseException = VALID_TEMPLATE,
        hec_responses: dict[str, list[dict[str, object]]] | None = None,
        put_error: BaseException | None = None,
        put_response: dict[str, object] | None = None,
    ):
        self.input_responses = deque(input_responses)
        self.template = template
        self.hec_responses = {
            category: deque(responses)
            for category, responses in (hec_responses or {}).items()
        }
        self.put_error = put_error
        self.put_response = put_response
        self.calls: list[tuple[str, object]] = []

    def login(self) -> None:
        self.calls.append(('login', None))

    def put_input(self, payload):
        self.calls.append(('put_input', copy.deepcopy(payload)))
        if self.put_error is not None:
            raise self.put_error
        return copy.deepcopy(self.put_response)

    def get_input(self):
        self.calls.append(('get_input', None))
        if not self.input_responses:
            raise AssertionError('No fake input response remains')
        response = (
            self.input_responses.popleft()
            if len(self.input_responses) > 1
            else self.input_responses[0]
        )
        if isinstance(response, BaseException):
            raise response
        return copy.deepcopy(response)

    def get_hec_token(self, category: str):
        self.calls.append(('get_hec_token', category))
        responses = self.hec_responses.get(category)
        if responses:
            response = (
                responses.popleft()
                if len(responses) > 1
                else responses[0]
            )
            return copy.deepcopy(response)
        return {'token': f'token-for-{category}'}

    def delete_hec_token(self, category: str) -> None:
        self.calls.append(('delete_hec_token', category))

    def get_template(self, input_document: dict[str, object]) -> bytes:
        self.calls.append(
            (
                'get_template',
                splunk_integration.template_suffix_for_input(input_document),
            )
        )
        if isinstance(self.template, BaseException):
            raise self.template
        return self.template

    def check_delete_readiness(self) -> None:
        self.calls.append(('check_delete_readiness', None))

    def delete_input(self) -> None:
        self.calls.append(('delete_input', None))


def runtime_config(
    request: dict[str, object] | None,
    *,
    username: str = 'splunk-user',
    password: str = 'splunk-password',
) -> object:
    return splunk_integration.RuntimeConfig(
        cloud_url='https://splunk.example.com',
        input_id='input-id',
        username=username,
        password=password,
        input_request=request,
    )


def runtime_values(
    request: dict[str, object] | None = None,
) -> dict[str, str]:
    values = {
        'SPLUNK_CLOUD': 'https://splunk.example.com',
        'SPLUNK_INPUT_UUID': 'input-id',
        'SPLUNK_CLOUD_USERNAME': 'splunk-user',
        'SPLUNK_CLOUD_PASSWORD': 'splunk-password',
    }
    if request is not None:
        values['SPLUNK_CLOUD_INPUT_JSON'] = json.dumps(request)
    return values


def install_runtime_environment(monkeypatch, request=None) -> None:
    for name, value in runtime_values(request).items():
        monkeypatch.setenv(name, value)


def test_entrypoint_runs_from_an_unrelated_directory(
    tmp_path: Path,
) -> None:
    result = subprocess.run(
        [sys.executable, str(SCRIPT_PATH), '--help'],
        cwd=tmp_path,
        check=False,
        capture_output=True,
        text=True,
    )

    assert result.returncode == 0
    assert '{create,get,delete}' in result.stdout
    assert result.stderr == ''
    assert list(tmp_path.iterdir()) == []


def test_runtime_config_does_not_expose_credentials() -> None:
    config = runtime_config(
        push_request(),
        username='user+private@example.com',
        password='password&private=true',
    )

    rendered = repr(config)

    assert 'user+private@example.com' not in rendered
    assert 'password&private=true' not in rendered


def test_diagnostic_redacts_nested_credentials_and_sensitive_tags() -> None:
    diagnostic = splunk_integration.render_diagnostic(
        {
            'password': 'payload-password',
            'nested': [
                {
                    'apiToken': 'payload-token',
                    'kmsKeyArns': ['arn:aws:kms:us-east-1:123:key/key-id'],
                }
            ],
            'resourceTags': [
                {'Key': 'Owner', 'Value': 'forge-team'},
                {'Key': 'ClientSecret', 'Value': 'tag-secret'},
            ],
        },
        limit=4096,
    )

    rendered = json.loads(diagnostic)
    assert rendered['password'] == '[REDACTED]'
    assert rendered['nested'][0]['apiToken'] == '[REDACTED]'
    assert rendered['nested'][0]['kmsKeyArns'] == [
        'arn:aws:kms:us-east-1:123:key/key-id'
    ]
    assert rendered['resourceTags'] == [
        {'Key': 'Owner', 'Value': 'forge-team'},
        {'Key': 'ClientSecret', 'Value': '[REDACTED]'},
    ]
    assert 'payload-password' not in diagnostic
    assert 'payload-token' not in diagnostic
    assert 'tag-secret' not in diagnostic


def test_http_error_body_is_single_line_redacted_and_bounded() -> None:
    body = b'upstream failed\npassword=body-secret\n' + (
        b'x' * (splunk_integration.HTTP_ERROR_BODY_LIMIT + 100)
    )

    diagnostic = splunk_integration.render_http_error_body(body)

    assert '\n' not in diagnostic
    assert 'body-secret' not in diagnostic
    assert 'password=[REDACTED]' in diagnostic
    assert '[truncated; total_chars=' in diagnostic


@pytest.mark.parametrize(
    ('body', 'secrets'),
    [
        (
            b'username=splunk%2B%22user%22&password=password%0Aprivate',
            ('splunk+"user"', 'password\nprivate'),
        ),
        (
            b'username=splunk+&quot;user&quot; password=password&#10;private',
            ('splunk+"user"', 'password\nprivate'),
        ),
        (
            b'{"apiToken":"server-secret"',
            (),
        ),
    ],
)
def test_non_json_http_error_body_does_not_leak_encoded_secrets(
    body: bytes,
    secrets: tuple[str, ...],
) -> None:
    diagnostic = splunk_integration.render_http_error_body(
        body,
        secret_values=secrets,
    )

    assert 'splunk' not in diagnostic
    assert 'private' not in diagnostic
    assert 'password%0Aprivate' not in diagnostic
    assert 'password\\nprivate' not in diagnostic
    assert 'server-secret' not in diagnostic
    assert '[REDACTED]' in diagnostic


def test_fetch_input_rejects_an_invalid_response() -> None:
    with pytest.raises(
        splunk_integration.SplunkIntegrationError,
        match='invalid data input response',
    ):
        splunk_integration.fetch_input(lambda: {'name': 'incomplete'})


def test_supported_s3_datasets_match_the_terraform_contract() -> None:
    assert splunk_integration.S3_DATASETS == frozenset(S3_DATASETS)


@pytest.mark.parametrize('dataset', S3_DATASETS)
def test_s3_datasets_use_queue_readiness(dataset: str) -> None:
    request = s3_request(dataset=dataset)
    response = s3_response(request=request)

    assert splunk_integration.input_uses_s3(request)
    assert splunk_integration.s3_input_state(response) == 'ready'
    assert splunk_integration.wait_for_input(
        fetch_sequence(response),
        request=request,
    ) == response


def test_s3_input_rejects_multiple_supported_datasets() -> None:
    request = s3_request()
    request['details']['datasetInfo']['ct-logs'] = {
        'sqsUrls': [{'sqsUrl': sqs_url('cloudtrail')}],
    }

    with pytest.raises(
        splunk_integration.SplunkIntegrationError,
        match='more than one supported S3 dataset',
    ):
        splunk_integration.input_uses_s3(request)


def test_s3_wait_retries_pending_input_until_every_queue_is_ready() -> None:
    request = s3_request(
        queue_urls=[sqs_url('queue-east'), sqs_url('queue-west', 'us-west-2')]
    )
    sleeps = []

    result = splunk_integration.wait_for_input(
        fetch_sequence(
            s3_response(
                'CreateDataSourceInProgress',
                include_stack_details=False,
                request=request,
            ),
            s3_response(
                request=request,
                status_count=1,
            ),
            s3_response(request=request),
        ),
        request=request,
        sleep=sleeps.append,
    )

    assert result['details']['stackName'] == 'SplunkDMSqsS3-input-id'
    assert len(result['dataSourcesStatus']) == 2
    assert sleeps == [5, 5]


def test_s3_wait_fails_immediately_on_provisioning_error() -> None:
    response = s3_response(
        'CreateDataSourceFailure',
        include_stack_details=False,
    )
    response['dataSourcesStatus'][s3_status_key(sqs_url('queue-0'))][
        'status'
    ]['token'] = 'server-token'
    calls = 0

    def fetch():
        nonlocal calls
        calls += 1
        return response

    with pytest.raises(
        splunk_integration.SplunkIntegrationError,
        match='provisioning failed',
    ) as raised:
        splunk_integration.wait_for_input(
            fetch,
            sleep=lambda _seconds: pytest.fail('failure must not retry'),
        )

    assert calls == 1
    assert 'server-token' not in str(raised.value)
    assert '[REDACTED]' in str(raised.value)


def test_s3_wait_rejects_stale_success_for_changed_request() -> None:
    old_request = s3_request(
        queue_urls=[sqs_url('old-queue')],
        s3_bucket_patterns=['old-bucket-*'],
        kms_key_arns=['arn:aws:kms:us-east-1:123:key/old'],
    )
    expected_request = s3_request(
        queue_urls=[sqs_url('new-queue')],
        s3_bucket_patterns=['new-bucket-*'],
        kms_key_arns=['arn:aws:kms:us-east-1:123:key/new'],
    )
    sleeps = []

    result = splunk_integration.wait_for_input(
        fetch_sequence(
            s3_response(request=old_request),
            s3_response(request=expected_request),
        ),
        request=expected_request,
        sleep=sleeps.append,
    )

    assert result['details']['datasetInfo'] == (
        expected_request['details']['datasetInfo']
    )
    assert result['details']['s3BucketPatterns'] == ['new-bucket-*']
    assert result['details']['kmsKeyArns'] == [
        'arn:aws:kms:us-east-1:123:key/new'
    ]
    assert sleeps == [5]


def test_s3_wait_rejects_stale_push_response_for_s3_request() -> None:
    request = s3_request()
    ready = s3_response(request=request)
    sleeps = []

    result = splunk_integration.wait_for_input(
        fetch_sequence(push_response(), ready),
        request=request,
        sleep=sleeps.append,
    )

    assert result == ready
    assert sleeps == [5]


def test_s3_wait_rejects_success_from_prior_put_metadata() -> None:
    request = s3_request()
    sleeps = []

    result = splunk_integration.wait_for_input(
        fetch_sequence(
            s3_response(
                request=request,
                version=2,
                last_update_time='2026-08-05 10:00:00+00:00',
            ),
            s3_response(
                request=request,
                version=2,
                last_update_time='2026-08-05 10:02:00+00:00',
            ),
        ),
        request=request,
        expected_version='2',
        expected_update_time='2026-08-05 10:01:00+00:00',
        sleep=sleeps.append,
    )

    assert result['details']['version'] == 2
    assert result['lastUpdateTime'] == '2026-08-05 10:02:00+00:00'
    assert sleeps == [5]


@pytest.mark.parametrize('status', [0, 404, 409, 429, 500, 503])
def test_s3_wait_retries_transient_input_fetches(status: int) -> None:
    sleeps = []

    result = splunk_integration.wait_for_input(
        fetch_sequence(
            splunk_integration.SplunkHttpError(status, 'transient'),
            s3_response(),
        ),
        sleep=sleeps.append,
    )

    assert result['details']['stackName'] == 'SplunkDMSqsS3-input-id'
    assert sleeps == [5]


@pytest.mark.parametrize('status', [400, 401, 403, 422])
def test_s3_wait_does_not_retry_non_retryable_fetches(
    status: int,
) -> None:
    calls = 0
    error = splunk_integration.SplunkHttpError(
        status,
        'permanent',
        '{"error":"response details"}',
    )

    def fetch():
        nonlocal calls
        calls += 1
        raise error

    with pytest.raises(
        splunk_integration.SplunkHttpError,
        match='permanent',
    ) as raised:
        splunk_integration.wait_for_input(
            fetch,
            sleep=lambda _seconds: pytest.fail('failure must not retry'),
        )

    assert calls == 1
    assert raised.value is error
    assert raised.value.status == status
    assert raised.value.response_body == '{"error":"response details"}'


def test_s3_wait_preserves_the_final_retryable_fetch_error() -> None:
    calls = 0
    sleeps = []
    error = splunk_integration.SplunkHttpError(
        503,
        'transient exhaustion',
        '{"error":"last response"}',
    )

    def fetch():
        nonlocal calls
        calls += 1
        raise error

    with pytest.raises(
        splunk_integration.SplunkHttpError,
        match='transient exhaustion',
    ) as raised:
        splunk_integration.wait_for_input(
            fetch,
            max_attempts=3,
            sleep=sleeps.append,
        )

    assert calls == 3
    assert sleeps == [5, 5]
    assert raised.value is error
    assert raised.value.status == 503
    assert raised.value.response_body == '{"error":"last response"}'


def test_s3_wait_stops_after_the_bounded_attempts() -> None:
    calls = 0

    def fetch():
        nonlocal calls
        calls += 1
        return s3_response(
            'CreateDataSourceInProgress',
            include_stack_details=False,
        )

    with pytest.raises(
        splunk_integration.SplunkIntegrationError,
        match='after 3 attempts',
    ):
        splunk_integration.wait_for_input(
            fetch,
            max_attempts=3,
            poll_interval_seconds=0,
            sleep=lambda _seconds: None,
        )

    assert calls == 3


def test_wait_returns_push_inputs_without_polling() -> None:
    document = push_response()
    calls = 0

    def fetch():
        nonlocal calls
        calls += 1
        return document

    assert splunk_integration.wait_for_input(fetch) == document
    assert calls == 1


@pytest.mark.parametrize(
    ('raw_template', 'valid'),
    [
        (b'{"Resources":{"Role":{}}}', True),
        (b'{"Resources":{}}', False),
        (b'{"Parameters":{}}', False),
        (b'not-json', False),
    ],
)
def test_cloudformation_template_validation(
    raw_template: bytes,
    valid: bool,
) -> None:
    assert (
        splunk_integration.validate_cloudformation_template(raw_template)
        is valid
    )


@pytest.mark.parametrize(
    ('dataset', 'expected_category'),
    PUSH_DATASET_CATEGORIES,
)
def test_push_datasets_keep_their_hec_category(
    dataset: str,
    expected_category: str,
) -> None:
    document = push_response((dataset, 'unsupported-dataset'))

    assert splunk_integration.dataset_hec_categories(document) == [
        (dataset, expected_category),
    ]


def test_create_preserves_the_initial_hec_delay_and_polling(
    tmp_path: Path,
) -> None:
    request = push_request(('cwl-lambda', 'cloudtrail'))
    client = FakeClient(
        input_responses=[push_response(('cwl-lambda', 'cloudtrail'))],
        hec_responses={
            'aws-cwl': [
                {'details': splunk_integration.NOAH_TOKEN_PENDING},
                {'token': 'aws-token'},
            ],
            'cloudtrail': [{'token': 'cloudtrail-token'}],
        },
    )
    sleeps: list[float] = []
    messages: list[str] = []
    template_path = tmp_path / 'input-id_template.json'

    splunk_integration.create_integration(
        client,
        request,
        template_path,
        sleep=sleeps.append,
        logger=messages.append,
    )

    assert sleeps == [300, 60]
    assert messages == [
        'Waiting 300 seconds for HEC token provisioning.',
        'HEC token exists for cloudtrail.',
        'HEC token creation is still in progress for aws-cwl.',
        'HEC token exists for aws-cwl.',
    ]
    assert client.calls == [
        ('put_input', request),
        ('get_input', None),
        ('get_hec_token', 'cloudtrail'),
        ('get_hec_token', 'aws-cwl'),
        ('get_hec_token', 'aws-cwl'),
        ('get_template', '/templates/dataaccount/ingest'),
    ]
    assert template_path.read_bytes() == VALID_TEMPLATE
    assert set(tmp_path.iterdir()) == {template_path}


@pytest.mark.parametrize('dataset', S3_DATASETS)
def test_create_s3_input_waits_for_current_readiness_before_template(
    tmp_path: Path,
    dataset: str,
) -> None:
    request = s3_request(dataset=dataset)
    put_response = s3_response(
        request=request,
        version=2,
        last_update_time='2026-08-05 10:01:00+00:00',
    )
    ready_response = s3_response(
        request=request,
        version=2,
        last_update_time='2026-08-05 10:03:00+00:00',
    )
    client = FakeClient(
        input_responses=[
            s3_response(
                request=request,
                version=1,
                last_update_time='2026-08-05 10:00:00+00:00',
            ),
            s3_response(
                'CreateDataSourceInProgress',
                request=request,
                version=2,
                last_update_time='2026-08-05 10:02:00+00:00',
            ),
            ready_response,
        ],
        put_response=put_response,
    )
    template_path = tmp_path / 'input-id_template.json'
    sleeps = []

    splunk_integration.create_integration(
        client,
        request,
        template_path,
        sleep=sleeps.append,
    )

    assert client.calls == [
        ('put_input', request),
        ('get_input', None),
        ('get_input', None),
        ('get_input', None),
        ('get_template', '/templates/s3/sqs'),
    ]
    assert sleeps == [5, 5]
    assert template_path.read_bytes() == VALID_TEMPLATE
    assert set(tmp_path.iterdir()) == {template_path}


def test_create_stops_after_a_failed_update(tmp_path: Path) -> None:
    request = push_request()
    client = FakeClient(
        put_error=splunk_integration.SplunkHttpError(500, 'PUT failed'),
    )
    template_path = tmp_path / 'input-id_template.json'

    with pytest.raises(splunk_integration.SplunkHttpError):
        splunk_integration.create_integration(
            client,
            request,
            template_path,
        )

    assert client.calls == [('put_input', request)]
    assert list(tmp_path.iterdir()) == []


def test_create_push_input_does_not_retry_a_failed_fetch(
    tmp_path: Path,
) -> None:
    request = push_request()
    client = FakeClient(
        input_responses=[
            splunk_integration.SplunkHttpError(500, 'GET failed')
        ]
    )

    with pytest.raises(
        splunk_integration.SplunkHttpError,
        match='GET failed',
    ):
        splunk_integration.create_integration(
            client,
            request,
            tmp_path / 'input-id_template.json',
            sleep=lambda _seconds: pytest.fail('push fetch must not retry'),
        )

    assert client.calls == [
        ('put_input', request),
        ('get_input', None),
    ]


def test_create_rejects_an_invalid_template_without_writing_it(
    tmp_path: Path,
) -> None:
    request = push_request()
    client = FakeClient(
        input_responses=[push_response()],
        template=b'{"Resources":{}}',
    )
    template_path = tmp_path / 'input-id_template.json'

    with pytest.raises(
        splunk_integration.SplunkIntegrationError,
        match='invalid CloudFormation template',
    ):
        splunk_integration.create_integration(
            client,
            request,
            template_path,
            sleep=lambda _seconds: None,
        )

    assert list(tmp_path.iterdir()) == []


def test_get_returns_only_version_and_raw_template_hash(
    tmp_path: Path,
) -> None:
    template = (
        b'{\n  "Resources": {"Role": {"Type": "AWS::IAM::Role"}}\n}\n'
    )
    client = FakeClient(
        input_responses=[push_response(version=12)],
        template=template,
    )
    template_path = tmp_path / 'input-id_template.json'

    result = splunk_integration.get_integration(
        client,
        template_path,
    )

    assert result == {
        'version': '12',
        'template_hash': hashlib.sha256(template).hexdigest(),
    }
    assert client.calls == [
        ('get_input', None),
        ('get_hec_token', 'cloudtrail'),
        ('get_template', '/templates/dataaccount/ingest'),
    ]
    assert template_path.read_bytes() == template
    assert set(tmp_path.iterdir()) == {template_path}


def test_get_waits_for_s3_readiness_before_fetching_template(
    tmp_path: Path,
) -> None:
    request = s3_request()
    pending = s3_response(
        'CreateDataSourceInProgress',
        include_stack_details=False,
        request=request,
    )
    ready = s3_response(request=request)
    client = FakeClient(
        input_responses=[pending, pending, ready],
    )
    sleeps = []

    result = splunk_integration.get_integration(
        client,
        tmp_path / 'input-id_template.json',
        sleep=sleeps.append,
    )

    assert result['version'] == '1'
    assert sleeps == [5]
    assert client.calls == [
        ('get_input', None),
        ('get_input', None),
        ('get_input', None),
        ('get_template', '/templates/s3/sqs'),
    ]


def test_delete_payload_removes_response_owned_fields() -> None:
    document = push_response()

    payload = splunk_integration.build_delete_payload(document)

    assert payload['mode'] == 'MarkedForDelete'
    assert all(
        field not in payload
        for field in splunk_integration.TOP_LEVEL_RESPONSE_FIELDS
    )
    assert all(
        field not in payload['details']
        for field in splunk_integration.DETAIL_RESPONSE_FIELDS
    )
    assert payload['details']['datasetInfo'] == {'cloudtrail': {}}
    assert document['mode'] == 'Complete'
    assert document['details']['version'] == 7


def test_delete_preserves_the_fixed_hec_cleanup_sequence() -> None:
    document = push_response()
    client = FakeClient(input_responses=[document])

    splunk_integration.delete_integration(client)

    delete_payload = splunk_integration.build_delete_payload(document)
    assert tuple(
        category
        for operation, category in client.calls
        if operation == 'delete_hec_token'
    ) == CLEANUP_CATEGORIES
    assert client.calls == [
        ('get_input', None),
        ('check_delete_readiness', None),
        ('put_input', delete_payload),
        ('check_delete_readiness', None),
        *[
            ('delete_hec_token', category)
            for category in CLEANUP_CATEGORIES
        ],
        ('check_delete_readiness', None),
        ('delete_input', None),
    ]


def test_delete_s3_input_skips_hec_cleanup_and_response_fields() -> None:
    document = s3_response()
    client = FakeClient(input_responses=[document])

    splunk_integration.delete_integration(client)

    put_payloads = [
        payload
        for operation, payload in client.calls
        if operation == 'put_input'
    ]
    assert len(put_payloads) == 1
    assert 'dataSourcesStatus' not in put_payloads[0]
    assert all(
        operation != 'delete_hec_token'
        for operation, _value in client.calls
    )
    assert client.calls[-1] == ('delete_input', None)


def test_delete_accepts_an_already_missing_input() -> None:
    client = FakeClient(
        input_responses=[
            splunk_integration.SplunkHttpError(404, 'missing')
        ]
    )

    splunk_integration.delete_integration(client)

    assert client.calls == [('get_input', None)]


class FakeResponse:
    def __init__(self, status: int, body: bytes):
        self.status = status
        self.body = body

    def __enter__(self):
        return self

    def __exit__(self, *_args) -> bool:
        return False

    def read(self) -> bytes:
        return self.body


class FakeOpener:
    def __init__(self, responses):
        self.responses = deque(responses)
        self.requests = []

    def open(self, request):
        self.requests.append(request)
        response = self.responses.popleft()
        if isinstance(response, BaseException):
            raise response
        return response


def authenticated_cookie_jar() -> http.cookiejar.CookieJar:
    cookies = http.cookiejar.CookieJar()
    for name, value in {
        'cval': 'cval-value',
        'splunkweb_uid': 'uid-value',
        'splunkweb_csrf_token_8443': 'csrf-value',
        'splunkd_8443': 'session-value',
        'AWSELB': 'affinity-value',
    }.items():
        cookies.set_cookie(
            http.cookiejar.Cookie(
                version=0,
                name=name,
                value=value,
                port=None,
                port_specified=False,
                domain='splunk.example.com',
                domain_specified=True,
                domain_initial_dot=False,
                path='/',
                path_specified=True,
                secure=True,
                expires=None,
                discard=True,
                comment=None,
                comment_url=None,
                rest={},
                rfc2109=False,
            )
        )
    return cookies


def request_headers(request) -> dict[str, str]:
    return {
        name.lower(): value
        for name, value in request.header_items()
    }


@pytest.mark.parametrize(
    'include_awselb',
    (True, False),
    ids=('with-awselb', 'without-awselb'),
)
def test_default_client_keeps_login_cookies_in_memory(
    include_awselb: bool,
) -> None:
    received: list[tuple[str, str, dict[str, str], bytes]] = []
    input_document = push_response()

    class LoginHandler(BaseHTTPRequestHandler):
        def log_message(self, _format, *_args) -> None:
            return

        def reply(self, body: bytes, *cookies: str) -> None:
            self.send_response(200)
            for cookie in cookies:
                self.send_header('Set-Cookie', cookie)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(body)

        def record(self) -> None:
            length = int(self.headers.get('Content-Length', '0'))
            body = self.rfile.read(length)
            received.append(
                (self.command, self.path, dict(self.headers), body)
            )

        def do_GET(self) -> None:
            self.record()
            if self.path == '/en-US/account/login?loginType=splunk':
                self.reply(
                    b'login',
                    'cval=cval-value; Path=/',
                    'splunkweb_uid=uid-value; Path=/',
                )
                return
            self.reply(json.dumps(input_document).encode())

        def do_POST(self) -> None:
            self.record()
            cookies = [
                'splunkweb_csrf_token_8443=csrf-value; Path=/',
                'splunkd_8443=session-value; Path=/',
            ]
            if include_awselb:
                cookies.append('AWSELB=affinity-value; Path=/')
            self.reply(
                b'authenticated',
                *cookies,
            )

    server = ThreadingHTTPServer(('127.0.0.1', 0), LoginHandler)
    server_thread = Thread(target=server.serve_forever, daemon=True)
    server_thread.start()
    try:
        config = splunk_integration.RuntimeConfig(
            cloud_url=f'http://127.0.0.1:{server.server_port}',
            input_id='input-id',
            username='splunk-user',
            password='splunk-password',
        )
        client = splunk_integration.SplunkWebClient(config)
        client.login()
        assert client.get_input() == input_document
    finally:
        server.shutdown()
        server.server_close()
        server_thread.join()

    assert received[1][0:2] == ('POST', '/en-GB/account/login')
    assert 'cval=cval-value' in received[1][2]['Cookie']
    assert parse_qs(received[1][3].decode())['username'] == [
        'splunk-user',
    ]
    assert received[2][0] == 'GET'
    assert received[2][2]['X-Splunk-Form-Key'] == 'csrf-value'
    assert 'splunkd_8443=session-value' in received[2][2]['Cookie']
    expected_cookie_names = {
        'cval',
        'splunkweb_uid',
        'splunkweb_csrf_token_8443',
        'splunkd_8443',
    }
    if include_awselb:
        expected_cookie_names.add('AWSELB')
    assert (
        'AWSELB=affinity-value' in received[2][2]['Cookie']
    ) is include_awselb
    assert {
        cookie.name
        for cookie in client.cookies
    } == expected_cookie_names


def test_client_encodes_login_and_authenticated_json_requests() -> None:
    request_payload = push_request(('cloudtrail', 'metadata'))
    update_response = push_response(('cloudtrail', 'metadata'))
    opener = FakeOpener(
        [
            FakeResponse(200, b'login'),
            FakeResponse(200, b'authenticated'),
            FakeResponse(200, splunk_integration.encode_json(update_response)),
        ]
    )
    messages: list[str] = []
    config = runtime_config(
        request_payload,
        username='splunk+user@example.com',
        password='password&second=value',
    )
    client = splunk_integration.SplunkWebClient(
        config,
        cookies=authenticated_cookie_jar(),
        opener=opener,
        logger=messages.append,
    )

    client.login()
    result = client.put_input(request_payload)

    login_request = opener.requests[1]
    assert login_request.full_url.endswith('/en-GB/account/login')
    assert parse_qs(login_request.data.decode()) == {
        'cval': ['cval-value'],
        'username': ['splunk+user@example.com'],
        'password': ['password&second=value'],
    }
    assert request_headers(login_request)['cookie'] == (
        'cval=cval-value; splunkweb_uid=uid-value'
    )

    api_request = opener.requests[2]
    assert api_request.get_method() == 'PUT'
    assert api_request.full_url.endswith(
        '/en-GB/splunkd/__raw/servicesNS/nobody/'
        'data_manager/cloudinput/inputs/input-id'
    )
    assert json.loads(api_request.data) == request_payload
    assert result == update_response
    headers = request_headers(api_request)
    assert headers['content-type'] == 'application/json'
    assert headers['x-splunk-form-key'] == 'csrf-value'
    assert headers['cookie'] == (
        'splunkweb_csrf_token_8443=csrf-value; '
        'splunk_csrf_token=csrf-value; '
        'splunkd_8443=session-value; '
        'AWSELB=affinity-value'
    )
    assert all(
        not any(
            secret in message
            for secret in (
                'splunk+user@example.com',
                'password&second=value',
                'csrf-value',
                'session-value',
            )
        )
        for message in messages
    )


@pytest.mark.parametrize(
    ('input_document', 'template_suffix'),
    (
        (push_response(), '/templates/dataaccount/ingest'),
        (s3_response(), '/templates/s3/sqs'),
    ),
    ids=('push', 's3'),
)
def test_client_routes_template_download_by_input_document(
    input_document: dict[str, object],
    template_suffix: str,
) -> None:
    opener = FakeOpener(
        [
            FakeResponse(200, b'login'),
            FakeResponse(200, b'authenticated'),
            FakeResponse(200, VALID_TEMPLATE),
        ]
    )
    client = splunk_integration.SplunkWebClient(
        runtime_config(None),
        cookies=authenticated_cookie_jar(),
        opener=opener,
    )

    client.login()
    result = client.get_template(input_document)

    assert result == VALID_TEMPLATE
    template_request = opener.requests[2]
    assert template_request.get_method() == 'GET'
    assert template_request.full_url == (
        'https://splunk.example.com/en-GB/splunkd/__raw/'
        'servicesNS/nobody/data_manager/cloudinput/inputs/input-id'
        f'{template_suffix}'
    )
    assert request_headers(template_request)['content-type'] == 'text/plain'


def test_client_preserves_only_a_sanitized_http_error_body() -> None:
    username = 'splunk+"user"'
    password = 'password\nprivate'
    response_body = json.dumps(
        {
            'message': (
                f'template failed for {username} with {password} '
                'and csrf-value'
            ),
            'token': 'server-token',
            'kmsKeyArns': ['arn:aws:kms:us-east-1:123:key/key-id'],
        }
    ).encode()
    opener = FakeOpener(
        [
            FakeResponse(200, b'login'),
            FakeResponse(200, b'authenticated'),
            FakeResponse(500, response_body),
        ]
    )
    client = splunk_integration.SplunkWebClient(
        runtime_config(
            s3_request(),
            username=username,
            password=password,
        ),
        cookies=authenticated_cookie_jar(),
        opener=opener,
    )
    client.login()

    with pytest.raises(
        splunk_integration.SplunkHttpError,
        match='returned HTTP 500',
    ) as raised:
        client.get_template(s3_response())

    error = raised.value
    assert error.status == 500
    assert 'server-token' not in error.response_body
    assert username not in error.response_body
    assert password not in error.response_body
    assert 'csrf-value' not in error.response_body
    assert json.loads(error.response_body) == {
        'kmsKeyArns': ['arn:aws:kms:us-east-1:123:key/key-id'],
        'message': (
            'template failed for [REDACTED] with [REDACTED] '
            'and [REDACTED]'
        ),
        'token': '[REDACTED]',
    }


def test_client_does_not_capture_unauthenticated_login_error_body() -> None:
    opener = FakeOpener(
        [
            FakeResponse(
                500,
                b'username=splunk-user&password=splunk-password',
            ),
        ]
    )
    client = splunk_integration.SplunkWebClient(
        runtime_config(s3_request()),
        cookies=authenticated_cookie_jar(),
        opener=opener,
    )

    with pytest.raises(splunk_integration.SplunkHttpError) as raised:
        client.login()

    assert raised.value.response_body is None


def test_client_tolerates_already_deleted_resources() -> None:
    opener = FakeOpener(
        [
            FakeResponse(200, b'login'),
            FakeResponse(200, b'authenticated'),
            FakeResponse(404, b'missing token'),
            FakeResponse(404, b'missing input'),
        ]
    )
    client = splunk_integration.SplunkWebClient(
        runtime_config(push_request()),
        cookies=authenticated_cookie_jar(),
        opener=opener,
    )
    client.login()

    client.delete_hec_token('cloudtrail')
    client.delete_input()

    assert [
        request.get_method()
        for request in opener.requests[2:]
    ] == ['DELETE', 'DELETE']


@pytest.mark.parametrize(
    ('status', 'body'),
    [
        (404, b'missing token'),
        (500, b'upstream failure'),
        (200, b'not-json'),
    ],
)
def test_client_preserves_best_effort_hec_token_checks(
    status: int,
    body: bytes,
) -> None:
    opener = FakeOpener(
        [
            FakeResponse(200, b'login'),
            FakeResponse(200, b'authenticated'),
            FakeResponse(status, body),
        ]
    )
    client = splunk_integration.SplunkWebClient(
        runtime_config(push_request()),
        cookies=authenticated_cookie_jar(),
        opener=opener,
    )
    client.login()

    assert client.get_hec_token('cloudtrail') == {}


def test_s3_template_failure_prints_response_body_and_request_payload(
    tmp_path: Path,
    monkeypatch,
) -> None:
    request = s3_request()
    response_body = splunk_integration.render_http_error_body(
        b'{"error":"template is not ready","token":"server-token"}'
    )
    input_response = s3_response(request=request)
    client = FakeClient(
        input_responses=[input_response],
        put_response=input_response,
        template=splunk_integration.SplunkHttpError(
            500,
            'GET /templates/s3/sqs returned HTTP 500',
            response_body,
        ),
    )

    monkeypatch.setattr(
        splunk_integration,
        'SplunkWebClient',
        lambda _config, logger: client,
    )
    install_runtime_environment(monkeypatch, request)
    stdout = io.StringIO()
    stderr = io.StringIO()

    result = splunk_integration.main(
        ['create'],
        output_stream=stdout,
        error_stream=stderr,
        artifact_dir=tmp_path,
    )

    lines = stderr.getvalue().splitlines()
    assert result == 1
    assert stdout.getvalue() == ''
    assert lines[0] == (
        'Splunk Data Manager create failed: '
        'GET /templates/s3/sqs returned HTTP 500'
    )
    assert lines[1] == (
        'Splunk HTTP response body: '
        '{"error":"template is not ready","token":"[REDACTED]"}'
    )
    payload = json.loads(
        lines[2].removeprefix(
            'Splunk Data Manager request payload (redacted): '
        )
    )
    assert payload['details']['datasetInfo'] == (
        request['details']['datasetInfo']
    )
    assert payload['details']['s3BucketPatterns'] == (
        request['details']['s3BucketPatterns']
    )
    assert payload['details']['kmsKeyArns'] == (
        request['details']['kmsKeyArns']
    )
    assert 'server-token' not in stderr.getvalue()
    assert list(tmp_path.iterdir()) == []


def test_create_main_uses_process_environment_and_only_writes_template(
    tmp_path: Path,
    monkeypatch,
) -> None:
    request = push_request()
    client = FakeClient(input_responses=[push_response()])
    captured = {}

    def client_factory(config, logger):
        captured['config'] = config
        logger(
            'GET /sanitized-create-diagnostic returned HTTP 200 for '
            f'{config.username} using {config.password}.'
        )
        return client

    real_create = splunk_integration.create_integration
    sleeps: list[float] = []

    def create_without_real_sleep(
        lifecycle_client,
        input_request,
        template_path,
        *,
        logger,
    ):
        return real_create(
            lifecycle_client,
            input_request,
            template_path,
            sleep=sleeps.append,
            logger=logger,
        )

    monkeypatch.setattr(
        splunk_integration,
        'SplunkWebClient',
        client_factory,
    )
    monkeypatch.setattr(
        splunk_integration,
        'create_integration',
        create_without_real_sleep,
    )
    install_runtime_environment(monkeypatch, request)
    stdout = io.StringIO()
    stderr = io.StringIO()

    result = splunk_integration.main(
        ['create'],
        output_stream=stdout,
        error_stream=stderr,
        artifact_dir=tmp_path,
    )

    assert result == 0
    assert stdout.getvalue() == ''
    assert stderr.getvalue().splitlines() == [
        'GET /sanitized-create-diagnostic returned HTTP 200 for '
        '[REDACTED] using [REDACTED].',
        'Waiting 300 seconds for HEC token provisioning.',
        'HEC token exists for cloudtrail.',
    ]
    assert 'splunk-user' not in stderr.getvalue()
    assert 'splunk-password' not in stderr.getvalue()
    assert captured['config'].input_request == request
    assert sleeps == [300]
    template_path = tmp_path / 'input-id_template.json'
    assert template_path.read_bytes() == VALID_TEMPLATE
    assert set(tmp_path.iterdir()) == {template_path}


def test_get_main_reads_the_external_query_and_prints_only_result_json(
    tmp_path: Path,
    monkeypatch,
) -> None:
    template = b'{"Resources":{"Role":{"Metadata":"raw bytes"}}}'
    client = FakeClient(
        input_responses=[push_response(version=19)],
        template=template,
    )
    captured = {}

    def client_factory(config, logger):
        captured['config'] = config
        logger('GET /buffered-external-diagnostic returned HTTP 200.')
        return client

    monkeypatch.setattr(
        splunk_integration,
        'SplunkWebClient',
        client_factory,
    )
    stdout = io.StringIO()
    stderr = io.StringIO()

    result = splunk_integration.main(
        ['get'],
        input_stream=io.StringIO(json.dumps(runtime_values())),
        output_stream=stdout,
        error_stream=stderr,
        artifact_dir=tmp_path,
    )

    assert result == 0
    assert stderr.getvalue() == ''
    assert captured['config'].input_request is None
    assert json.loads(stdout.getvalue()) == {
        'version': '19',
        'template_hash': hashlib.sha256(template).hexdigest(),
    }
    assert stdout.getvalue().count('\n') == 1
    template_path = tmp_path / 'input-id_template.json'
    assert template_path.read_bytes() == template
    assert set(tmp_path.iterdir()) == {template_path}


def test_get_failure_keeps_response_body_out_of_external_stdout(
    tmp_path: Path,
    monkeypatch,
) -> None:
    client = FakeClient(
        input_responses=[s3_response()],
        template=splunk_integration.SplunkHttpError(
            500,
            'GET /templates/s3/sqs returned HTTP 500',
            '{"error":"template is not ready"}',
        ),
    )

    monkeypatch.setattr(
        splunk_integration,
        'SplunkWebClient',
        lambda _config, logger: client,
    )
    stdout = io.StringIO()
    stderr = io.StringIO()

    result = splunk_integration.main(
        ['get'],
        input_stream=io.StringIO(json.dumps(runtime_values())),
        output_stream=stdout,
        error_stream=stderr,
        artifact_dir=tmp_path,
    )

    assert result == 1
    assert stdout.getvalue() == ''
    assert stderr.getvalue().splitlines() == [
        'Splunk Data Manager get failed: '
        'GET /templates/s3/sqs returned HTTP 500',
        'Splunk HTTP response body: '
        '{"error":"template is not ready"}',
    ]
    assert 'splunk-user' not in stderr.getvalue()
    assert 'splunk-password' not in stderr.getvalue()
    assert list(tmp_path.iterdir()) == []


def test_delete_main_uses_process_environment_without_artifacts(
    tmp_path: Path,
    monkeypatch,
) -> None:
    client = FakeClient(input_responses=[push_response()])
    captured = {}

    def client_factory(config, logger):
        captured['config'] = config
        return client

    monkeypatch.setattr(
        splunk_integration,
        'SplunkWebClient',
        client_factory,
    )
    install_runtime_environment(monkeypatch)
    stdout = io.StringIO()
    stderr = io.StringIO()

    result = splunk_integration.main(
        ['delete'],
        output_stream=stdout,
        error_stream=stderr,
        artifact_dir=tmp_path,
    )

    assert result == 0
    assert stdout.getvalue() == ''
    assert stderr.getvalue() == ''
    assert captured['config'].input_request is None
    assert client.calls[0] == ('login', None)
    assert client.calls[-1] == ('delete_input', None)
    assert list(tmp_path.iterdir()) == []


def test_main_prints_failure_diagnostics_only_to_stderr(
    tmp_path: Path,
    monkeypatch,
) -> None:
    request = push_request()
    request['diagnostic'] = {
        'password': 'payload-password',
        'resourceTags': [
            {'Key': 'ApiToken', 'Value': 'payload-token'},
        ],
    }
    client = FakeClient(
        put_error=splunk_integration.SplunkHttpError(
            500,
            'PUT failed for splunk-user using splunk-user-password',
        ),
    )

    def client_factory(config, logger):
        logger(
            f'PUT response for {config.username} '
            f'using {config.password}.'
        )
        return client

    monkeypatch.setattr(
        splunk_integration,
        'SplunkWebClient',
        client_factory,
    )
    install_runtime_environment(monkeypatch, request)
    monkeypatch.setenv('SPLUNK_CLOUD_USERNAME', 'splunk-user')
    monkeypatch.setenv('SPLUNK_CLOUD_PASSWORD', 'splunk-user-password')
    stdout = io.StringIO()
    stderr = io.StringIO()

    result = splunk_integration.main(
        ['create'],
        output_stream=stdout,
        error_stream=stderr,
        artifact_dir=tmp_path,
    )

    assert result == 1
    assert stdout.getvalue() == ''
    lines = stderr.getvalue().splitlines()
    assert lines[:2] == [
        'PUT response for [REDACTED] using [REDACTED].',
        'Splunk Data Manager create failed: '
        'PUT failed for [REDACTED] using [REDACTED]',
    ]
    payload = json.loads(
        lines[2].removeprefix(
            'Splunk Data Manager request payload (redacted): '
        )
    )
    assert payload['diagnostic'] == {
        'password': '[REDACTED]',
        'resourceTags': [
            {'Key': 'ApiToken', 'Value': '[REDACTED]'},
        ],
    }
    assert 'splunk-user' not in stderr.getvalue()
    assert 'splunk-password' not in stderr.getvalue()
    assert 'payload-password' not in stderr.getvalue()
    assert 'payload-token' not in stderr.getvalue()
    assert list(tmp_path.iterdir()) == []
