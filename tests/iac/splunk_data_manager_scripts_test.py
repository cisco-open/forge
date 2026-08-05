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
    return splunk_integration.RuntimeConfig(
        cloud_url='https://splunk.example.com',
        input_id='input-id',
        username='splunk-user',
        password='splunk-password',
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


def test_supported_s3_datasets_match_the_terraform_contract() -> None:
    assert splunk_integration.S3_DATASETS == frozenset(S3_DATASETS)


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


@pytest.mark.parametrize('dataset', S3_DATASETS)
def test_s3_datasets_use_queue_readiness(dataset: str) -> None:
    request = s3_request(dataset=dataset)
    response = s3_response(
        'CreateDataSourceSuccess',
        request=request,
    )

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


def test_s3_wait_retries_an_in_progress_response() -> None:
    sleeps = []
    result = splunk_integration.wait_for_input(
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
        splunk_integration.SplunkIntegrationError,
        match='provisioning failed',
    ):
        splunk_integration.wait_for_input(
            fetch_sequence(response),
            sleep=lambda _seconds: None,
        )


def test_s3_wait_requires_success_for_every_configured_queue() -> None:
    result = splunk_integration.wait_for_input(
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
        s3_bucket_patterns=['old-bucket-*'],
    )
    expected_request = s3_request(
        s3_bucket_patterns=['new-bucket-*'],
    )

    result = splunk_integration.wait_for_input(
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


def test_s3_wait_rejects_stale_success_for_changed_kms_keys() -> None:
    old_request = s3_request(kms_key_arns=['arn:aws:kms:::key/old'])
    expected_request = s3_request(kms_key_arns=['arn:aws:kms:::key/new'])

    result = splunk_integration.wait_for_input(
        fetch_sequence(
            s3_response('CreateDataSourceSuccess', request=old_request),
            s3_response('CreateDataSourceSuccess', request=expected_request),
        ),
        request=expected_request,
        sleep=lambda _seconds: None,
    )

    assert result['details']['kmsKeyArns'] == [
        'arn:aws:kms:::key/new',
    ]


def test_s3_wait_rejects_a_replaced_queues_stale_success() -> None:
    old_url = sqs_url('logs_old', region='eu-west-1')
    new_url = sqs_url('logs', region='eu-west-1')
    request = s3_request(queue_urls=[new_url])

    result = splunk_integration.wait_for_input(
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
    result = splunk_integration.wait_for_input(
        fetch_sequence(
            s3_response('CreateDataSourceSuccess', version=1),
            s3_response('CreateDataSourceSuccess', version=2),
        ),
        expected_version='2',
        sleep=lambda _seconds: None,
    )

    assert result['details']['version'] == 2


def test_s3_wait_rejects_success_from_an_older_update() -> None:
    result = splunk_integration.wait_for_input(
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
    result = splunk_integration.wait_for_input(
        fetch_sequence(
            splunk_integration.SplunkHttpError(status, 'transient'),
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
        raise splunk_integration.SplunkHttpError(status, 'permanent')

    with pytest.raises(
        splunk_integration.SplunkIntegrationError,
        match='non-retryable',
    ):
        splunk_integration.wait_for_input(
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


def test_wait_returns_push_inputs_without_s3_polling() -> None:
    document = push_input()

    assert splunk_integration.wait_for_input(
        fetch_sequence(document)
    ) == document


def test_wait_rejects_an_invalid_input_response() -> None:
    with pytest.raises(
        splunk_integration.SplunkIntegrationError,
        match='invalid data input response',
    ):
        splunk_integration.wait_for_input(fetch_sequence({'name': 'bad'}))


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

    assert splunk_integration.dataset_hec_categories(document) == [
        (dataset, expected),
    ]


@pytest.mark.parametrize('dataset', S3_DATASETS)
def test_s3_inputs_do_not_request_hec_tokens(dataset: str) -> None:
    client = FakeClient()
    request = s3_request(dataset=dataset)

    splunk_integration.ensure_hec_tokens(
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
    assert 'dataSourcesStatus' in document
    assert 'stackName' in document['details']


@pytest.mark.parametrize('dataset', S3_DATASETS)
def test_create_s3_input_writes_only_template_without_hec_sleep(
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
    template_path = tmp_path / 'input-id_template.json'

    splunk_integration.create_integration(
        client,
        request,
        template_path,
        sleep=lambda _seconds: pytest.fail('S3 input slept for HEC'),
    )

    assert template_path.read_bytes() == template
    assert set(tmp_path.iterdir()) == {template_path}
    assert not any(call[0] == 'get_hec_token' for call in client.calls)


def test_create_s3_input_preserves_all_configured_lists(
    tmp_path: Path,
) -> None:
    request = s3_request(
        queue_urls=[
            sqs_url('queue-east', 'us-east-1'),
            sqs_url('queue-west', 'us-west-2'),
        ],
        s3_bucket_patterns=['forge-a-*', 'forge-b-*'],
        kms_key_arns=[
            'arn:aws:kms:us-east-1:166060576821:key/key-a',
            'arn:aws:kms:us-west-2:166060576821:key/key-b',
        ],
    )
    response = s3_response('CreateDataSourceSuccess', request=request)
    client = FakeClient(
        input_responses=[response],
        put_response=response,
    )
    template_path = tmp_path / 'input-id_template.json'

    splunk_integration.create_integration(
        client,
        request,
        template_path,
        sleep=lambda _seconds: pytest.fail('ready S3 input slept'),
    )

    assert client.calls[0] == ('put_input', request)
    assert len(response['dataSourcesStatus']) == 2
    assert response['details']['s3BucketPatterns'] == [
        'forge-a-*',
        'forge-b-*',
    ]
    assert len(response['details']['kmsKeyArns']) == 2
    assert set(tmp_path.iterdir()) == {template_path}


def test_create_stops_on_a_failed_put(tmp_path: Path) -> None:
    client = FakeClient(
        put_response=splunk_integration.SplunkHttpError(
            500,
            'PUT failed',
        )
    )
    template_path = tmp_path / 'input-id_template.json'

    with pytest.raises(splunk_integration.SplunkHttpError):
        splunk_integration.create_integration(
            client,
            s3_request(),
            template_path,
        )

    assert client.calls == [('put_input', s3_request())]
    assert list(tmp_path.iterdir()) == []


def test_create_push_input_preserves_hec_waiting(
    tmp_path: Path,
) -> None:
    request = push_input(('cwl-lambda', 'cloudtrail'))
    client = FakeClient(
        input_responses=[request],
        put_response=None,
        hec_responses={
            'aws-cwl': [
                {'details': splunk_integration.NOAH_TOKEN_PENDING},
                {'token': 'aws-token'},
            ],
            'cloudtrail': [{'token': 'trail-token'}],
        },
    )
    template_path = tmp_path / 'input-id_template.json'
    sleeps = []

    splunk_integration.create_integration(
        client,
        request,
        template_path,
        sleep=sleeps.append,
    )

    assert sleeps == [300, 60]
    assert [
        value
        for operation, value in client.calls
        if operation == 'get_hec_token'
    ] == ['cloudtrail', 'aws-cwl', 'aws-cwl']
    assert set(tmp_path.iterdir()) == {template_path}


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
    template_path = tmp_path / 'input-id_template.json'

    result = splunk_integration.get_integration(
        client,
        request,
        template_path,
    )

    assert result == {
        'version': '1',
        'template_hash': hashlib.sha256(template).hexdigest(),
        'stack_name': 'SplunkDMSqsS3-input-id',
    }
    assert template_path.read_bytes() == template
    assert set(tmp_path.iterdir()) == {template_path}


@pytest.mark.parametrize('dataset', S3_DATASETS)
def test_delete_s3_input_skips_hec_cleanup(
    dataset: str,
) -> None:
    request = s3_request(dataset=dataset)
    response = s3_response('CreateDataSourceSuccess', request=request)
    client = FakeClient(
        input_responses=[response],
    )

    splunk_integration.delete_integration(client)

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


def test_delete_push_input_preserves_full_hec_cleanup() -> None:
    client = FakeClient(input_responses=[push_input()])

    splunk_integration.delete_integration(client)

    deleted_categories = [
        category
        for operation, category in client.calls
        if operation == 'delete_hec_token'
    ]
    assert deleted_categories == list(
        splunk_integration.PUSH_HEC_CLEANUP_CATEGORIES
    )


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


def test_default_client_keeps_login_cookies_in_memory() -> None:
    received: list[tuple[str, str, dict[str, str], bytes]] = []
    input_document = push_input()

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

        def record(self) -> bytes:
            length = int(self.headers.get('Content-Length', '0'))
            body = self.rfile.read(length)
            received.append(
                (self.command, self.path, dict(self.headers), body)
            )
            return body

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
            self.reply(
                b'authenticated',
                'splunkweb_csrf_token_8443=csrf-value; Path=/',
                'splunkd_8443=session-value; Path=/',
                'AWSELB=affinity-value; Path=/',
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
    assert {
        cookie.name
        for cookie in client.cookies
    } == {
        'cval',
        'splunkweb_uid',
        'splunkweb_csrf_token_8443',
        'splunkd_8443',
        'AWSELB',
    }


def test_client_preserves_login_cookies_and_csrf_headers() -> None:
    input_document = push_input()
    opener = FakeOpener(
        [
            FakeResponse(200, b'login'),
            FakeResponse(200, b'authenticated'),
            FakeResponse(
                200,
                json.dumps(input_document).encode(),
            ),
        ]
    )
    log_messages = []
    config = runtime_config(input_document)
    client = splunk_integration.SplunkWebClient(
        config,
        cookies=authenticated_cookie_jar(),
        opener=opener,
        logger=log_messages.append,
    )

    client.login()
    assert client.get_input() == input_document

    assert opener.requests[0].full_url.endswith(
        '/en-US/account/login?loginType=splunk'
    )
    assert opener.requests[1].full_url.endswith('/en-GB/account/login')
    assert request_headers(opener.requests[1])['cookie'] == (
        'cval=cval-value; splunkweb_uid=uid-value'
    )
    login_form = parse_qs(opener.requests[1].data.decode())
    assert login_form == {
        'cval': ['cval-value'],
        'username': ['splunk-user'],
        'password': ['splunk-password'],
    }

    api_request = opener.requests[2]
    assert api_request.get_method() == 'GET'
    assert api_request.full_url.endswith(
        '/en-GB/splunkd/__raw/servicesNS/nobody/'
        'data_manager/cloudinput/inputs/input-id'
    )
    headers = request_headers(api_request)
    assert headers['x-splunk-form-key'] == 'csrf-value'
    assert headers['cookie'] == (
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
    opener = FakeOpener(
        [
            FakeResponse(200, b'login'),
            FakeResponse(200, b'authenticated'),
            FakeResponse(404, b'missing token'),
            FakeResponse(404, b'missing input'),
        ]
    )
    client = splunk_integration.SplunkWebClient(
        runtime_config(push_input()),
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
        runtime_config(push_input()),
        cookies=authenticated_cookie_jar(),
        opener=opener,
    )
    client.login()

    assert client.get_hec_token('cloudtrail') == {}


def test_create_main_uses_environment_and_writes_only_template(
    tmp_path: Path,
    monkeypatch,
) -> None:
    request = s3_request()
    response = s3_response('CreateDataSourceSuccess', request=request)
    template = b'{"Resources":{"Role":{}}}'
    client = FakeClient(
        input_responses=[response],
        put_response=response,
        template=template,
    )
    monkeypatch.setattr(
        splunk_integration,
        'SplunkWebClient',
        lambda _config, logger: client,
    )
    for name, value in runtime_values(request).items():
        monkeypatch.setenv(name, value)
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
    assert stderr.getvalue() == ''
    assert client.calls[:2] == [
        ('login', None),
        ('put_input', request),
    ]
    template_path = tmp_path / 'input-id_template.json'
    assert template_path.read_bytes() == template
    assert set(tmp_path.iterdir()) == {template_path}


def test_delete_main_uses_environment_without_artifacts(
    tmp_path: Path,
    monkeypatch,
) -> None:
    client = FakeClient(input_responses=[push_input()])
    monkeypatch.setattr(
        splunk_integration,
        'SplunkWebClient',
        lambda _config, logger: client,
    )
    for name, value in runtime_values().items():
        monkeypatch.setenv(name, value)
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
    assert client.calls[0] == ('login', None)
    assert client.calls[-1] == ('delete_input', None)
    assert list(tmp_path.iterdir()) == []


def test_create_main_keeps_diagnostics_in_memory_until_failure(
    tmp_path: Path,
    monkeypatch,
) -> None:
    request = s3_request()
    client = FakeClient(
        put_response=splunk_integration.SplunkHttpError(500, 'PUT failed')
    )

    def client_factory(_config, logger):
        logger('PUT response retained in memory.')
        return client

    monkeypatch.setattr(
        splunk_integration,
        'SplunkWebClient',
        client_factory,
    )
    for name, value in runtime_values(request).items():
        monkeypatch.setenv(name, value)
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
    assert stderr.getvalue().splitlines() == [
        'PUT response retained in memory.',
        'Splunk Data Manager create failed: PUT failed',
    ]
    assert list(tmp_path.iterdir()) == []


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
    query = runtime_values(request)
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
    template_path = tmp_path / 'input-id_template.json'
    assert template_path.read_bytes() == template
    assert set(tmp_path.iterdir()) == {template_path}
