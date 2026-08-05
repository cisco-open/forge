"""Unit tests for the Splunk Data Manager Python lifecycle command."""

from __future__ import annotations

import copy
import hashlib
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
splunk_api = importlib.import_module('splunk_api')
splunk_lifecycle = importlib.import_module('splunk_lifecycle')
splunk_integration = importlib.import_module('splunk_integration')

AWS_ACCOUNT_ID = '166060576821'
S3_DATASETS = (
    's3-custom-logs',
    'ct-logs',
    's3-access-logs',
    'elb-access-logs',
    'cf-access-logs',
)


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
        queue_urls = [sqs_url('queue-0')]
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
        dataset_info['sourceType'] = 'forgecicd:runner-logs:s3'

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
            'datasetInfo': {
                dataset: dataset_info,
            },
            'dataAccounts': [AWS_ACCOUNT_ID],
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

    dataset = next(iter(request['details']['datasetInfo']))
    configured_urls = [
        entry['sqsUrl']
        for entry in request['details']['datasetInfo'][dataset][
            'sqsUrls'
        ]
    ]
    if status_count is None:
        status_count = len(configured_urls)
    if status_queue_urls is None:
        status_queue_urls = configured_urls[:status_count]

    response = copy.deepcopy(request)
    if include_stack_details:
        response['details'].update(
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


def push_input(
    datasets: tuple[str, ...] = ('cloudtrail',),
) -> dict[str, object]:
    return {
        'name': 'forge-push-logs',
        'type': 'AWS',
        'destination': {
            'type': 'index',
            'details': {'cloudtrail': 'forge-index'},
        },
        'mode': 'Complete',
        'details': {
            'type': 'SingleAccount',
            'datasetInfo': {
                dataset: {}
                for dataset in datasets
            },
            'stackName': 'SplunkDMDataIngest-input-id',
            'version': 7,
        },
        'id': 'input-id',
    }


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
        put_response=None,
        template: bytes = b'{"Resources":{"Role":{"Type":"AWS::IAM::Role"}}}',
        hec_responses: dict[str, list[dict[str, object]]] | None = None,
    ):
        self.input_responses = deque(input_responses)
        self.put_response = put_response
        self.template = template
        self.hec_responses = {
            category: deque(responses)
            for category, responses in (hec_responses or {}).items()
        }
        self.calls: list[tuple[str, object]] = []

    def login(self) -> None:
        self.calls.append(('login', None))

    def put_input(self, payload):
        self.calls.append(('put_input', copy.deepcopy(payload)))
        if isinstance(self.put_response, BaseException):
            raise self.put_response
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

    def get_template(self) -> bytes:
        self.calls.append(('get_template', None))
        return self.template

    def check_delete_readiness(self) -> None:
        self.calls.append(('check_delete_readiness', None))

    def delete_input(self) -> None:
        self.calls.append(('delete_input', None))


def runtime_config(
    request: dict[str, object] | None,
) -> object:
    return splunk_api.RuntimeConfig(
        cloud_url='https://splunk.example.com',
        input_id='input-id',
        username='splunk-user',
        password='splunk-password',
        input_request=request,
    )


def test_supported_s3_datasets_match_the_terraform_contract() -> None:
    assert splunk_lifecycle.S3_DATASETS == frozenset(S3_DATASETS)


def test_entrypoint_loads_sibling_modules_from_unrelated_directory(
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


@pytest.mark.parametrize(
    ('operation', 'handler_name'),
    (
        ('create', 'handle_create'),
        ('delete', 'handle_delete'),
    ),
)
def test_main_dispatches_environment_commands(
    operation: str,
    handler_name: str,
    tmp_path: Path,
    monkeypatch,
) -> None:
    calls = []
    environment = {'COMMAND': operation}

    def handler(values, artifact_dir) -> None:
        calls.append((values, artifact_dir))

    monkeypatch.setattr(splunk_integration, handler_name, handler)

    result = splunk_integration.main(
        [operation],
        environ=environment,
        error_stream=io.StringIO(),
        artifact_dir=tmp_path,
    )

    assert result == 0
    assert calls == [(environment, tmp_path)]


@pytest.mark.parametrize('dataset', S3_DATASETS)
def test_s3_datasets_use_queue_readiness(dataset: str) -> None:
    request = s3_request(dataset=dataset)
    response = s3_response(
        'CreateDataSourceSuccess',
        request=request,
    )

    assert splunk_lifecycle.input_uses_s3(request)
    assert splunk_lifecycle.s3_input_state(response) == 'ready'
    assert splunk_lifecycle.wait_for_input(
        fetch_sequence(response),
        request=request,
    ) == response


def test_s3_input_rejects_multiple_supported_datasets() -> None:
    request = s3_request()
    request['details']['datasetInfo']['ct-logs'] = {
        'sqsUrls': [{'sqsUrl': sqs_url('cloudtrail')}],
    }

    with pytest.raises(
        splunk_api.SplunkIntegrationError,
        match='more than one supported S3 dataset',
    ):
        splunk_lifecycle.input_uses_s3(request)


def test_s3_wait_retries_an_in_progress_response() -> None:
    sleeps = []
    result = splunk_lifecycle.wait_for_input(
        fetch_sequence(
            s3_response(
                'CreateDataSourceInProgress',
                include_stack_details=False,
            ),
            s3_response('CreateDataSourceSuccess'),
        ),
        sleep=sleeps.append,
    )

    assert result['details']['stackName'] == 'SplunkDMSqsS3-input-id'
    assert sleeps == [5]


def test_s3_wait_fails_immediately_on_provisioning_error() -> None:
    response = s3_response(
        'CreateDataSourceFailure',
        include_stack_details=False,
    )

    with pytest.raises(
        splunk_api.SplunkIntegrationError,
        match='provisioning failed',
    ):
        splunk_lifecycle.wait_for_input(
            fetch_sequence(response),
            sleep=lambda _seconds: None,
        )


def test_s3_wait_requires_success_for_every_configured_queue() -> None:
    result = splunk_lifecycle.wait_for_input(
        fetch_sequence(
            s3_response(
                'CreateDataSourceSuccess',
                queue_count=2,
                status_count=1,
            ),
            s3_response('CreateDataSourceSuccess', queue_count=2),
        ),
        sleep=lambda _seconds: None,
    )

    assert len(result['dataSourcesStatus']) == 2


def test_s3_wait_rejects_stale_success_for_a_changed_request() -> None:
    old_request = s3_request(
        queue_urls=[sqs_url('old-queue')],
        s3_bucket_patterns=['old-bucket-*'],
    )
    expected_request = s3_request(
        queue_urls=[sqs_url('new-queue')],
        s3_bucket_patterns=['new-bucket-*'],
    )

    result = splunk_lifecycle.wait_for_input(
        fetch_sequence(
            s3_response(
                'CreateDataSourceSuccess',
                request=old_request,
            ),
            s3_response(
                'CreateDataSourceSuccess',
                request=expected_request,
            ),
        ),
        request=expected_request,
        sleep=lambda _seconds: None,
    )

    assert result['details']['s3BucketPatterns'] == ['new-bucket-*']


def test_s3_wait_rejects_a_replaced_queues_stale_success() -> None:
    old_url = sqs_url('logs_old', region='eu-west-1')
    new_url = sqs_url('logs', region='eu-west-1')
    request = s3_request(queue_urls=[new_url])

    result = splunk_lifecycle.wait_for_input(
        fetch_sequence(
            s3_response(
                'CreateDataSourceSuccess',
                request=request,
                status_queue_urls=[old_url],
            ),
            s3_response(
                'CreateDataSourceSuccess',
                request=request,
            ),
        ),
        request=request,
        sleep=lambda _seconds: None,
    )

    assert list(result['dataSourcesStatus']) == [s3_status_key(new_url)]


def test_s3_wait_rejects_success_from_an_older_version() -> None:
    result = splunk_lifecycle.wait_for_input(
        fetch_sequence(
            s3_response('CreateDataSourceSuccess', version=1),
            s3_response('CreateDataSourceSuccess', version=2),
        ),
        expected_version='2',
        sleep=lambda _seconds: None,
    )

    assert result['details']['version'] == 2


def test_s3_wait_rejects_success_from_an_older_update() -> None:
    result = splunk_lifecycle.wait_for_input(
        fetch_sequence(
            s3_response(
                'CreateDataSourceSuccess',
                last_update_time='old',
            ),
            s3_response(
                'CreateDataSourceSuccess',
                last_update_time='new',
            ),
        ),
        expected_update_time='new',
        sleep=lambda _seconds: None,
    )

    assert result['lastUpdateTime'] == 'new'


@pytest.mark.parametrize('status', [0, 404, 409, 429, 500, 503])
def test_s3_wait_retries_transient_fetch_errors(status: int) -> None:
    result = splunk_lifecycle.wait_for_input(
        fetch_sequence(
            splunk_api.SplunkHttpError(status, 'transient'),
            s3_response('CreateDataSourceSuccess'),
        ),
        sleep=lambda _seconds: None,
    )

    assert result['details']['stackName'] == 'SplunkDMSqsS3-input-id'


@pytest.mark.parametrize('status', [400, 401, 403, 422])
def test_s3_wait_does_not_retry_non_retryable_fetches(
    status: int,
) -> None:
    calls = 0

    def fetch():
        nonlocal calls
        calls += 1
        raise splunk_api.SplunkHttpError(status, 'permanent')

    with pytest.raises(
        splunk_api.SplunkIntegrationError,
        match='non-retryable',
    ):
        splunk_lifecycle.wait_for_input(
            fetch,
            sleep=lambda _seconds: None,
        )

    assert calls == 1


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
        splunk_api.SplunkIntegrationError,
        match='after 3 attempts',
    ):
        splunk_lifecycle.wait_for_input(
            fetch,
            max_attempts=3,
            poll_interval_seconds=0,
            sleep=lambda _seconds: None,
        )

    assert calls == 3


def test_wait_returns_push_inputs_without_s3_polling() -> None:
    document = push_input()

    assert splunk_lifecycle.wait_for_input(
        fetch_sequence(document)
    ) == document


def test_wait_rejects_an_invalid_input_response() -> None:
    with pytest.raises(
        splunk_api.SplunkIntegrationError,
        match='invalid data input response',
    ):
        splunk_lifecycle.wait_for_input(fetch_sequence({'name': 'bad'}))


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
        splunk_lifecycle.validate_cloudformation_template(raw_template)
        is valid
    )


@pytest.mark.parametrize(
    ('dataset', 'expected'),
    [
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
    ],
)
def test_push_datasets_keep_their_hec_category(
    dataset: str,
    expected: str,
) -> None:
    document = push_input((dataset, 'unknown-dataset'))

    assert splunk_lifecycle.dataset_hec_categories(document) == [
        (dataset, expected),
    ]


@pytest.mark.parametrize('dataset', S3_DATASETS)
def test_s3_inputs_do_not_request_hec_tokens(dataset: str) -> None:
    client = FakeClient()
    request = s3_request(dataset=dataset)

    splunk_lifecycle.ensure_hec_tokens(
        client,
        s3_response('CreateDataSourceSuccess', request=request),
        initial_delay_seconds=300,
        sleep=lambda _seconds: pytest.fail('S3 input slept for HEC'),
    )

    assert client.calls == []


def test_delete_payload_removes_response_owned_fields() -> None:
    document = s3_response('CreateDataSourceSuccess')
    document.update({'_key': 'input-id', '_user': 'nobody'})
    document['details'].update(
        {
            'resources': {'us-east-1': []},
            'resourceTags': {'Product': 'Forge'},
        }
    )

    payload = splunk_lifecycle.build_delete_payload(document)

    assert payload['mode'] == 'MarkedForDelete'
    assert all(
        field not in payload
        for field in splunk_lifecycle.TOP_LEVEL_RESPONSE_FIELDS
    )
    assert all(
        field not in payload['details']
        for field in splunk_lifecycle.DETAIL_RESPONSE_FIELDS
    )
    assert 'dataSourcesStatus' in document
    assert 'stackName' in document['details']


@pytest.mark.parametrize('dataset', S3_DATASETS)
def test_create_s3_input_writes_artifacts_without_hec_sleep(
    tmp_path: Path,
    dataset: str,
) -> None:
    request = s3_request(dataset=dataset)
    response = s3_response(
        'CreateDataSourceSuccess',
        request=request,
    )
    template = b'{"Resources":{"QueueRole":{"Type":"AWS::IAM::Role"}}}'
    client = FakeClient(
        input_responses=[response],
        put_response=response,
        template=template,
    )
    paths = splunk_lifecycle.ArtifactPaths.for_input(
        'input-id',
        artifact_dir=tmp_path,
    )

    splunk_lifecycle.create_integration(
        client,
        runtime_config(request),
        paths,
        sleep=lambda _seconds: pytest.fail('S3 input slept for HEC'),
    )

    assert json.loads(paths.input_json.read_text()) == response
    assert paths.template_json.read_bytes() == template
    assert not any(call[0] == 'get_hec_token' for call in client.calls)


def test_create_stops_on_a_failed_put(tmp_path: Path) -> None:
    client = FakeClient(
        put_response=splunk_api.SplunkHttpError(
            500,
            'PUT failed',
        )
    )
    paths = splunk_lifecycle.ArtifactPaths.for_input(
        'input-id',
        artifact_dir=tmp_path,
    )

    with pytest.raises(splunk_api.SplunkHttpError):
        splunk_lifecycle.create_integration(
            client,
            runtime_config(s3_request()),
            paths,
        )

    assert client.calls == [('put_input', s3_request())]
    assert not paths.template_json.exists()


def test_create_push_input_preserves_hec_waiting(
    tmp_path: Path,
) -> None:
    request = push_input(('cwl-lambda', 'cloudtrail'))
    client = FakeClient(
        input_responses=[request],
        put_response=None,
        hec_responses={
            'aws-cwl': [
                {'details': splunk_lifecycle.NOAH_TOKEN_PENDING},
                {'token': 'aws-token'},
            ],
            'cloudtrail': [{'token': 'trail-token'}],
        },
    )
    paths = splunk_lifecycle.ArtifactPaths.for_input(
        'input-id',
        artifact_dir=tmp_path,
    )
    sleeps = []

    splunk_lifecycle.create_integration(
        client,
        runtime_config(request),
        paths,
        sleep=sleeps.append,
    )

    assert sleeps == [300, 60]
    assert [
        value
        for operation, value in client.calls
        if operation == 'get_hec_token'
    ] == ['cloudtrail', 'aws-cwl', 'aws-cwl']


def test_get_returns_string_result_and_hashes_raw_template(
    tmp_path: Path,
) -> None:
    request = s3_request()
    response = s3_response(
        'CreateDataSourceSuccess',
        request=request,
    )
    template = b'{\n  "Resources": {"Role": {"Type": "AWS::IAM::Role"}}\n}\n'
    client = FakeClient(
        input_responses=[response],
        template=template,
    )
    paths = splunk_lifecycle.ArtifactPaths.for_input(
        'input-id',
        artifact_dir=tmp_path,
    )

    result = splunk_lifecycle.get_integration(
        client,
        runtime_config(request),
        paths,
    )

    assert result == {
        'version': '1',
        'template_hash': hashlib.sha256(template).hexdigest(),
        'stack_name': 'SplunkDMSqsS3-input-id',
    }
    assert paths.template_json.read_bytes() == template


@pytest.mark.parametrize('dataset', S3_DATASETS)
def test_delete_s3_input_skips_hec_cleanup(
    tmp_path: Path,
    dataset: str,
) -> None:
    request = s3_request(dataset=dataset)
    response = s3_response('CreateDataSourceSuccess', request=request)
    client = FakeClient(
        input_responses=[response],
    )
    paths = splunk_lifecycle.ArtifactPaths.for_input(
        'input-id',
        artifact_dir=tmp_path,
    )

    splunk_lifecycle.delete_integration(client, paths)

    operations = [operation for operation, _value in client.calls]
    assert operations == [
        'get_input',
        'check_delete_readiness',
        'put_input',
        'check_delete_readiness',
        'check_delete_readiness',
        'delete_input',
    ]
    assert 'dataSourcesStatus' not in client.calls[2][1]


def test_delete_push_input_preserves_full_hec_cleanup(
    tmp_path: Path,
) -> None:
    client = FakeClient(input_responses=[push_input()])
    paths = splunk_lifecycle.ArtifactPaths.for_input(
        'input-id',
        artifact_dir=tmp_path,
    )

    splunk_lifecycle.delete_integration(client, paths)

    deleted_categories = [
        category
        for operation, category in client.calls
        if operation == 'delete_hec_token'
    ]
    assert deleted_categories == list(
        splunk_lifecycle.PUSH_HEC_CLEANUP_CATEGORIES
    )


def test_delete_accepts_an_already_missing_input(tmp_path: Path) -> None:
    client = FakeClient(
        input_responses=[
            splunk_api.SplunkHttpError(404, 'missing')
        ]
    )
    paths = splunk_lifecycle.ArtifactPaths.for_input(
        'input-id',
        artifact_dir=tmp_path,
    )

    splunk_lifecycle.delete_integration(client, paths)

    assert client.calls == [('get_input', None)]


class FakeTransport:
    def __init__(self, responses):
        self.responses = deque(responses)
        self.requests = []
        self.cookie_values = {
            'cval': 'cval-value',
            'splunkweb_uid': 'uid-value',
            'splunkweb_csrf_token_8443': 'csrf-value',
            'splunkd_8443': 'session-value',
            'AWSELB': 'affinity-value',
        }

    def request(self, method, url, *, headers=None, body=None):
        self.requests.append(
            {
                'method': method,
                'url': url,
                'headers': dict(headers or {}),
                'body': body,
            }
        )
        return self.responses.popleft()

    def cookie_value(self, name: str) -> str:
        return self.cookie_values[name]


def test_urllib_transport_handles_redirect_cookies_and_http_errors() -> None:
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, _format, *args) -> None:
            return

        def do_GET(self) -> None:
            if self.path == '/redirect':
                self.send_response(302)
                self.send_header('Location', '/login')
                self.end_headers()
                return
            if self.path == '/login':
                self.send_response(200)
                self.send_header(
                    'Set-Cookie',
                    'cval=cval-value; Path=/',
                )
                self.send_header(
                    'Set-Cookie',
                    'splunkweb_uid=uid-value; Path=/',
                )
                self.end_headers()
                self.wfile.write(b'logged in')
                return
            self.send_response(503)
            self.end_headers()
            self.wfile.write(b'unavailable')

    server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    server_thread = Thread(target=server.serve_forever, daemon=True)
    server_thread.start()
    try:
        base_url = f'http://127.0.0.1:{server.server_port}'
        transport = splunk_api.UrllibTransport()

        redirected = transport.request('GET', f'{base_url}/redirect')
        failed = transport.request('GET', f'{base_url}/error')

        assert redirected == splunk_api.HttpResponse(
            200,
            b'logged in',
        )
        assert transport.cookie_value('cval') == 'cval-value'
        assert transport.cookie_value('splunkweb_uid') == 'uid-value'
        assert failed == splunk_api.HttpResponse(
            503,
            b'unavailable',
        )
    finally:
        server.shutdown()
        server.server_close()
        server_thread.join(timeout=5)


def test_client_preserves_login_cookies_and_csrf_headers() -> None:
    input_document = push_input()
    transport = FakeTransport(
        [
            splunk_api.HttpResponse(200, b'login'),
            splunk_api.HttpResponse(200, b'authenticated'),
            splunk_api.HttpResponse(
                200,
                json.dumps(input_document).encode(),
            ),
        ]
    )
    log_messages = []
    config = runtime_config(input_document)
    client = splunk_api.SplunkWebClient(
        config,
        transport=transport,
        logger=log_messages.append,
    )

    client.login()
    assert client.get_input() == input_document

    assert transport.requests[0]['url'].endswith(
        '/en-US/account/login?loginType=splunk'
    )
    assert transport.requests[1]['url'].endswith('/en-GB/account/login')
    assert transport.requests[1]['headers']['Cookie'] == (
        'cval=cval-value; splunkweb_uid=uid-value'
    )
    login_form = parse_qs(transport.requests[1]['body'].decode())
    assert login_form == {
        'cval': ['cval-value'],
        'username': ['splunk-user'],
        'password': ['splunk-password'],
    }

    api_request = transport.requests[2]
    assert api_request['method'] == 'GET'
    assert api_request['url'].endswith(
        '/en-GB/splunkd/__raw/servicesNS/nobody/'
        'data_manager/cloudinput/inputs/input-id'
    )
    assert api_request['headers']['X-Splunk-Form-Key'] == 'csrf-value'
    assert api_request['headers']['Cookie'] == (
        'splunkweb_csrf_token_8443=csrf-value; '
        'splunk_csrf_token=csrf-value; '
        'splunkd_8443=session-value; '
        'AWSELB=affinity-value'
    )
    assert 'splunk-password' not in repr(config)
    assert all(
        not any(
            secret in message
            for secret in (
                'splunk-password',
                'csrf-value',
                'session-value',
            )
        )
        for message in log_messages
    )


def test_client_tolerates_already_deleted_resources() -> None:
    transport = FakeTransport(
        [
            splunk_api.HttpResponse(200, b'login'),
            splunk_api.HttpResponse(200, b'authenticated'),
            splunk_api.HttpResponse(404, b'missing token'),
            splunk_api.HttpResponse(404, b'missing input'),
        ]
    )
    client = splunk_api.SplunkWebClient(
        runtime_config(push_input()),
        transport=transport,
    )
    client.login()

    client.delete_hec_token('cloudtrail')
    client.delete_input()

    assert [
        request['method']
        for request in transport.requests[2:]
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
    transport = FakeTransport(
        [
            splunk_api.HttpResponse(200, b'login'),
            splunk_api.HttpResponse(200, b'authenticated'),
            splunk_api.HttpResponse(status, body),
        ]
    )
    client = splunk_api.SplunkWebClient(
        runtime_config(push_input()),
        transport=transport,
    )
    client.login()

    assert client.get_hec_token('cloudtrail') == {}


def test_get_main_writes_only_external_provider_json(
    tmp_path: Path,
    monkeypatch,
) -> None:
    request = s3_request()
    response = s3_response(
        'CreateDataSourceSuccess',
        request=request,
    )
    template = b'{"Resources":{"Role":{}}}'
    client = FakeClient(
        input_responses=[response],
        template=template,
    )
    monkeypatch.setattr(
        splunk_integration,
        'SplunkWebClient',
        lambda _config, logger: client,
    )
    query = {
        'SPLUNK_CLOUD': 'https://splunk.example.com',
        'SPLUNK_INPUT_UUID': 'input-id',
        'SPLUNK_CLOUD_USERNAME': 'splunk-user',
        'SPLUNK_CLOUD_PASSWORD': 'splunk-password',
        'SPLUNK_CLOUD_INPUT_JSON': json.dumps(request),
    }
    stdout = io.StringIO()
    stderr = io.StringIO()

    result = splunk_integration.main(
        ['get'],
        input_stream=io.StringIO(json.dumps(query)),
        output_stream=stdout,
        error_stream=stderr,
        artifact_dir=tmp_path,
    )

    assert result == 0
    assert stderr.getvalue() == ''
    assert json.loads(stdout.getvalue()) == {
        'version': '1',
        'template_hash': hashlib.sha256(template).hexdigest(),
        'stack_name': 'SplunkDMSqsS3-input-id',
    }
    assert stdout.getvalue().count('\n') == 1
