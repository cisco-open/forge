#!/usr/bin/env python3
"""Manage Splunk Cloud Data Manager inputs for Terraform."""

from __future__ import annotations

import argparse
import copy
import hashlib
import http.cookiejar
import json
import os
import re
import sys
import tempfile
import time
from collections.abc import Callable, Mapping, Sequence
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode, urlsplit
from urllib.request import HTTPCookieProcessor, Request, build_opener

JsonObject = dict[str, Any]
Logger = Callable[[str], None]

S3_DATASET = 's3-custom-logs'
NOAH_TOKEN_PENDING = 'Noah stack token creation in progress'
S3_STATUS_HOST = re.compile(
    r'^sqs\.(?P<region>[^.]+)\.amazonaws\.com(?:\.cn)?$'
)

DATASET_HEC_CATEGORIES = {
    'cwl-api-gateway': 'aws-cwl',
    'cwl-cloudhsm': 'aws-cwl',
    'cwl-documentDB': 'aws-cwl',
    'cwl-eks': 'aws-cwl',
    'cwl-lambda': 'aws-cwl',
    'cwl-rds': 'aws-cwl',
    'cwl-custom-logs': 'cwl-custom-logs',
    'cwl-vpc-flow-logs': 'cwl-vpc-flow-logs',
    'cloudtrail': 'cloudtrail',
    'securityhub': 'securityhub',
    'guardduty': 'guardduty',
    'iam-aa': 'iam-aa',
    'iam-cr': 'iam-cr',
    'metadata': 'metadata',
}

PUSH_HEC_CLEANUP_CATEGORIES = (
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

TOP_LEVEL_RESPONSE_FIELDS = (
    '_key',
    '_user',
    'createTime',
    'dataSourcesStatus',
    'id',
    'lastUpdateTime',
    'schemaVersion',
)

DETAIL_RESPONSE_FIELDS = (
    'stackName',
    'version',
    'resources',
    'resourceTags',
)


class SplunkIntegrationError(RuntimeError):
    """Raised when a Splunk Data Manager lifecycle operation cannot continue."""


class SplunkHttpError(SplunkIntegrationError):
    """Raised for an unsuccessful Splunk HTTP request."""

    def __init__(self, status: int, message: str):
        super().__init__(message)
        self.status = status

    @property
    def retryable(self) -> bool:
        """Return whether an input fetch may be retried."""
        return self.status == 0 or self.status in {
            404,
            409,
            429,
        } or self.status >= 500


@dataclass(frozen=True, slots=True)
class HttpResponse:
    """Minimal HTTP response used by the Splunk client."""

    status: int
    body: bytes


@dataclass(frozen=True, slots=True)
class RuntimeConfig:
    """Runtime values supplied by Terraform."""

    cloud_url: str
    input_id: str
    username: str = field(repr=False)
    password: str = field(repr=False)
    input_request: JsonObject | None = field(default=None, repr=False)


@dataclass(frozen=True, slots=True)
class ArtifactPaths:
    """Local artifacts consumed by the Terraform module."""

    input_json: Path
    template_json: Path
    log: Path

    @classmethod
    def for_input(
        cls,
        input_id: str,
        *,
        artifact_dir: Path = Path('/tmp'),
    ) -> ArtifactPaths:
        """Build the established artifact paths for an input."""
        return cls(
            input_json=artifact_dir / f'{input_id}_input.json',
            template_json=artifact_dir / f'{input_id}_template.json',
            log=artifact_dir / f'{input_id}_logs.txt',
        )


class FileLogger:
    """Append lifecycle diagnostics to the input-specific log file."""

    def __init__(self, path: Path):
        self.path = path

    def __call__(self, message: str) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        with self.path.open('a', encoding='utf-8') as log:
            log.write(f'{message}\n')


class UrllibTransport:
    """HTTP transport with a cookie jar for the two-step Splunk login."""

    def __init__(self):
        self.cookies = http.cookiejar.CookieJar()
        self.opener = build_opener(HTTPCookieProcessor(self.cookies))

    def request(
        self,
        method: str,
        url: str,
        *,
        headers: Mapping[str, str] | None = None,
        body: bytes | None = None,
    ) -> HttpResponse:
        """Send one request and retain HTTP error responses for classification."""
        request = Request(
            url,
            data=body,
            headers=dict(headers or {}),
            method=method,
        )
        try:
            with self.opener.open(request) as response:
                return HttpResponse(
                    status=response.status,
                    body=response.read(),
                )
        except HTTPError as error:
            return HttpResponse(status=error.code, body=error.read())
        except URLError as error:
            raise SplunkHttpError(
                0,
                f'{method} request to Splunk failed at the transport layer',
            ) from error

    def cookie_value(self, name: str) -> str:
        """Return the most recently stored cookie value with the given name."""
        values = [
            cookie.value
            for cookie in self.cookies
            if cookie.name == name
        ]
        if not values:
            raise SplunkIntegrationError(
                f'Splunk login did not return the required {name} cookie'
            )
        return values[-1]


class SplunkWebClient:
    """Authenticated client for the Splunk Data Manager web endpoints."""

    _browser_headers = {
        'Sec-Fetch-Dest': 'empty',
        'Sec-Fetch-Mode': 'cors',
        'Sec-Fetch-Site': 'same-origin',
        'X-Requested-With': 'XMLHttpRequest',
    }

    def __init__(
        self,
        config: RuntimeConfig,
        *,
        transport: UrllibTransport | None = None,
        logger: Logger | None = None,
    ):
        self.config = config
        self.cloud_url = config.cloud_url.rstrip('/')
        self.transport = transport or UrllibTransport()
        self.logger = logger or (lambda _message: None)
        self._csrf_token: str | None = None
        self._cookie_header: str | None = None

    @property
    def input_path(self) -> str:
        """Return the locale-specific Data Manager input API path."""
        return (
            '/en-GB/splunkd/__raw/servicesNS/nobody/'
            f'data_manager/cloudinput/inputs/{self.config.input_id}'
        )

    def login(self) -> None:
        """Perform the established two-step Splunk Web login."""
        self.logger('Performing initial login to Splunk Cloud.')
        self._send(
            'GET',
            '/en-US/account/login?loginType=splunk',
        )

        cval = self.transport.cookie_value('cval')
        splunkweb_uid = self.transport.cookie_value('splunkweb_uid')
        login_body = urlencode(
            {
                'cval': cval,
                'username': self.config.username,
                'password': self.config.password,
            }
        ).encode('utf-8')

        self.logger('Performing second login to Splunk Cloud.')
        self._send(
            'POST',
            '/en-GB/account/login',
            headers={
                **self._browser_headers,
                'Content-Type': 'application/x-www-form-urlencoded',
                'Cookie': (
                    f'cval={cval}; splunkweb_uid={splunkweb_uid}'
                ),
            },
            body=login_body,
        )

        csrf_token = self.transport.cookie_value(
            'splunkweb_csrf_token_8443'
        )
        splunkd = self.transport.cookie_value('splunkd_8443')
        awselb = self.transport.cookie_value('AWSELB')
        self._csrf_token = csrf_token
        self._cookie_header = '; '.join(
            (
                f'splunkweb_csrf_token_8443={csrf_token}',
                f'splunk_csrf_token={csrf_token}',
                f'splunkd_8443={splunkd}',
                f'AWSELB={awselb}',
            )
        )

    def put_input(self, payload: JsonObject) -> JsonObject | None:
        """Create or update the configured input."""
        response = self._api_request(
            'PUT',
            self.input_path,
            content_type='application/json',
            body=_encode_json(payload),
        )
        if not response.body:
            return None
        try:
            return _decode_json(response.body, 'input update response')
        except SplunkIntegrationError:
            return None

    def get_input(self) -> JsonObject:
        """Fetch the current Data Manager input document."""
        response = self._api_request(
            'GET',
            self.input_path,
            content_type='text/plain',
        )
        return _decode_json(response.body, 'input response')

    def get_hec_token(self, category: str) -> JsonObject:
        """Fetch the HEC token status for a push-based dataset."""
        query = urlencode({'dataset': category})
        try:
            response = self._api_request(
                'GET',
                (
                    '/en-US/splunkd/__raw/servicesNS/nobody/'
                    'data_manager/cloudinput/inputs/'
                    f'{self.config.input_id}/hectoken?{query}'
                ),
                content_type='application/json',
            )
        except SplunkHttpError:
            return {}
        try:
            return _decode_json(response.body, 'HEC token response')
        except SplunkIntegrationError:
            # Existing push inputs treat unavailable or unexpected token
            # responses as best-effort and continue to template retrieval.
            return {}

    def delete_hec_token(self, category: str) -> None:
        """Delete the HEC token for a push-based dataset category."""
        query = urlencode({'dataset': category})
        try:
            self._api_request(
                'DELETE',
                (
                    '/en-US/splunkd/__raw/servicesNS/nobody/'
                    'data_manager/cloudinput/inputs/'
                    f'{self.config.input_id}/hectoken?{query}'
                ),
                content_type='text/plain',
            )
        except SplunkHttpError as error:
            if error.status != 404:
                raise

    def get_template(self) -> bytes:
        """Download the CloudFormation template for the input."""
        response = self._api_request(
            'GET',
            f'{self.input_path}/templates/dataaccount/ingest',
            content_type='text/plain',
        )
        return response.body

    def check_delete_readiness(self) -> None:
        """Ask Splunk to validate whether the input may be deleted."""
        self._api_request(
            'GET',
            f'{self.input_path}/validate/checkdeletereadiness',
            content_type='application/json',
        )

    def delete_input(self) -> None:
        """Delete the Data Manager input."""
        try:
            self._api_request(
                'DELETE',
                (
                    '/en-US/splunkd/__raw/servicesNS/nobody/'
                    f'data_manager/cloudinput/inputs/{self.config.input_id}'
                ),
                content_type='text/plain',
            )
        except SplunkHttpError as error:
            if error.status != 404:
                raise

    def _api_request(
        self,
        method: str,
        path: str,
        *,
        content_type: str,
        body: bytes | None = None,
    ) -> HttpResponse:
        if self._csrf_token is None or self._cookie_header is None:
            raise SplunkIntegrationError(
                'Splunk client must log in before calling the API'
            )
        return self._send(
            method,
            path,
            headers={
                **self._browser_headers,
                'Accept': 'application/json, text/plain, */*',
                'Content-Type': content_type,
                'Cookie': self._cookie_header,
                'X-Splunk-Form-Key': self._csrf_token,
            },
            body=body,
        )

    def _send(
        self,
        method: str,
        path: str,
        *,
        headers: Mapping[str, str] | None = None,
        body: bytes | None = None,
    ) -> HttpResponse:
        response = self.transport.request(
            method,
            f'{self.cloud_url}{path}',
            headers=headers,
            body=body,
        )
        self.logger(f'{method} {path} returned HTTP {response.status}.')
        if not 200 <= response.status < 300:
            raise SplunkHttpError(
                response.status,
                f'{method} {path} returned HTTP {response.status}',
            )
        return response


def _encode_json(payload: JsonObject) -> bytes:
    return json.dumps(payload, separators=(',', ':')).encode('utf-8')


def _decode_json(raw: bytes, description: str) -> JsonObject:
    try:
        document = json.loads(raw)
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise SplunkIntegrationError(
            f'Splunk returned an invalid {description}'
        ) from error
    if not isinstance(document, dict):
        raise SplunkIntegrationError(
            f'Splunk returned a non-object {description}'
        )
    return document


def validate_input_document(document: object) -> bool:
    """Return whether a request or response has a datasetInfo object."""
    if not isinstance(document, dict):
        return False
    details = document.get('details')
    return isinstance(details, dict) and isinstance(
        details.get('datasetInfo'),
        dict,
    )


def input_uses_s3(document: JsonObject) -> bool:
    """Return whether the input contains the pull-based S3 dataset."""
    if not validate_input_document(document):
        return False
    return S3_DATASET in document['details']['datasetInfo']


def s3_input_matches_request(
    actual: JsonObject,
    requested: JsonObject,
) -> bool:
    """Compare only request-owned fields in an S3 input response."""
    if not validate_input_document(actual):
        return False
    if not validate_input_document(requested):
        return False

    for key in ('name', 'type', 'destination', 'mode'):
        if actual.get(key) != requested.get(key):
            return False

    detail_keys = (
        'type',
        'iamRegion',
        'datasetInfo',
        'dataAccounts',
        's3BucketPatterns',
        'kmsKeyArns',
    )
    actual_details = actual['details']
    requested_details = requested['details']
    return {
        key: actual_details.get(key)
        for key in detail_keys
    } == {
        key: requested_details.get(key)
        for key in detail_keys
    }


def _s3_status_key(queue_url: str, input_id: str) -> str:
    parsed = urlsplit(queue_url)
    host_match = S3_STATUS_HOST.fullmatch(parsed.hostname or '')
    path_parts = parsed.path.strip('/').split('/')
    valid_host = parsed.scheme == 'https' and host_match is not None
    valid_path = len(path_parts) == 2
    if valid_path:
        valid_path = path_parts[0].isdigit() and bool(path_parts[1])
    if not valid_host or not valid_path:
        raise SplunkIntegrationError(
            f'Invalid SQS queue URL in Splunk input: {queue_url}'
        )
    return (
        f'scc_{host_match.group("region")}_{path_parts[1]}_{input_id}'
    )


def s3_input_state(document: JsonObject) -> str:
    """Classify S3 provisioning as pending, ready, or failed."""
    if not validate_input_document(document) or not input_uses_s3(document):
        raise SplunkIntegrationError(
            'Cannot classify a non-S3 Data Manager input'
        )

    input_id = document.get('id') or document.get('_key') or ''
    details = document['details']
    s3_dataset = details['datasetInfo'][S3_DATASET]
    if not isinstance(s3_dataset, dict):
        raise SplunkIntegrationError(
            'Splunk returned invalid S3 dataset metadata'
        )
    queue_entries = s3_dataset.get('sqsUrls', [])
    if not isinstance(queue_entries, list):
        raise SplunkIntegrationError(
            'Splunk returned invalid S3 queue status metadata'
        )

    queue_urls = [
        entry.get('sqsUrl', '')
        for entry in queue_entries
        if isinstance(entry, dict)
    ]
    if len(queue_urls) != len(queue_entries):
        raise SplunkIntegrationError(
            'Splunk returned invalid S3 queue status metadata'
        )

    expected_keys = [
        _s3_status_key(queue_url, str(input_id))
        for queue_url in queue_urls
    ]
    status_map = document.get('dataSourcesStatus', {})
    if not isinstance(status_map, dict):
        raise SplunkIntegrationError(
            'Splunk returned invalid dataSourcesStatus metadata'
        )

    states = []
    for key in expected_keys:
        status_entry = status_map.get(key)
        if not isinstance(status_entry, dict):
            states.append('')
            continue
        status = status_entry.get('status')
        state = status.get('state', '') if isinstance(status, dict) else ''
        states.append(state if isinstance(state, str) else '')

    if any(
        'fail' in state.lower() or 'error' in state.lower()
        for state in states
    ):
        return 'failed'
    if any(
        (
            not details.get('stackName'),
            details.get('version') is None,
            not input_id,
            not expected_keys,
            len(expected_keys) != len(queue_entries),
            any(not state for state in states),
        )
    ):
        return 'pending'
    if all(state.endswith('Success') for state in states):
        return 'ready'
    return 'pending'


def wait_for_input(
    fetch: Callable[[], JsonObject],
    *,
    request: JsonObject | None = None,
    expected_version: str | None = None,
    expected_update_time: str | None = None,
    max_attempts: int = 60,
    poll_interval_seconds: int = 5,
    sleep: Callable[[float], None] = time.sleep,
) -> JsonObject:
    """Fetch until the input is current and every S3 queue is ready."""
    for attempt in range(1, max_attempts + 1):
        try:
            document = fetch()
        except SplunkHttpError as error:
            if not error.retryable:
                raise SplunkIntegrationError(
                    'Splunk input fetch failed with a non-retryable '
                    f'HTTP {error.status} response'
                ) from error
            if attempt == max_attempts:
                break
            sleep(poll_interval_seconds)
            continue

        if not validate_input_document(document):
            raise SplunkIntegrationError(
                'Splunk returned an invalid data input response'
            )
        if not input_uses_s3(document):
            return document

        matches_expected_update = request is None or s3_input_matches_request(
            document,
            request,
        )
        if expected_version is not None:
            matches_expected_update = all(
                (
                    matches_expected_update,
                    document['details'].get('version') is not None,
                    str(document['details']['version']) == expected_version,
                )
            )
        if expected_update_time is not None:
            matches_expected_update = all(
                (
                    matches_expected_update,
                    document.get('lastUpdateTime') == expected_update_time,
                )
            )

        state = (
            s3_input_state(document)
            if matches_expected_update
            else 'pending'
        )
        if state == 'ready':
            return document
        if state == 'failed':
            status = json.dumps(
                document.get('dataSourcesStatus', {}),
                separators=(',', ':'),
            )
            raise SplunkIntegrationError(
                f'Splunk S3 data source provisioning failed: {status}'
            )
        if attempt < max_attempts:
            sleep(poll_interval_seconds)

    raise SplunkIntegrationError(
        f'Splunk S3 data source was not ready after {max_attempts} attempts'
    )


def validate_cloudformation_template(raw_template: bytes) -> bool:
    """Require a JSON CloudFormation template with non-empty Resources."""
    try:
        template = json.loads(raw_template)
    except (UnicodeDecodeError, json.JSONDecodeError):
        return False
    if not isinstance(template, dict):
        return False
    resources = template.get('Resources')
    return isinstance(resources, dict) and bool(resources)


def atomic_write(path: Path, content: bytes) -> None:
    """Atomically replace an artifact in its destination directory."""
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary_path: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(
            dir=path.parent,
            prefix=f'.{path.name}.',
            delete=False,
        ) as temporary:
            temporary.write(content)
            temporary_path = Path(temporary.name)
        os.replace(temporary_path, path)
    finally:
        if temporary_path is not None:
            temporary_path.unlink(missing_ok=True)


def dataset_hec_categories(
    document: JsonObject,
) -> list[tuple[str, str]]:
    """Map dataset names to the established push-input HEC categories."""
    if not validate_input_document(document):
        raise SplunkIntegrationError(
            'Cannot map HEC categories from an invalid input'
        )
    categories = []
    for dataset in sorted(document['details']['datasetInfo']):
        category = DATASET_HEC_CATEGORIES.get(dataset)
        if category is not None:
            categories.append((dataset, category))
    return categories


def ensure_hec_tokens(
    client: SplunkWebClient,
    document: JsonObject,
    *,
    initial_delay_seconds: int,
    sleep: Callable[[float], None] = time.sleep,
    logger: Logger | None = None,
) -> None:
    """Wait for all push-input HEC tokens; S3 inputs have none."""
    log = logger or (lambda _message: None)
    categories = dataset_hec_categories(document)
    if categories and initial_delay_seconds:
        sleep(initial_delay_seconds)

    for dataset, category in categories:
        while True:
            token_response = client.get_hec_token(category)
            if token_response.get('details') == NOAH_TOKEN_PENDING:
                log(
                    'HEC token creation is still in progress for '
                    f'dataset {category}.'
                )
                sleep(60)
                continue
            if token_response.get('token'):
                log(f'HEC token exists for dataset {category}.')
                break
            log(
                'Skipping unexpected HEC token response for '
                f'dataset {dataset}.'
            )
            break


def build_delete_payload(
    document: JsonObject,
    *,
    mode: str = 'MarkedForDelete',
) -> JsonObject:
    """Remove response-owned fields before updating deletion mode."""
    payload = copy.deepcopy(document)
    payload['mode'] = mode
    for field_name in TOP_LEVEL_RESPONSE_FIELDS:
        payload.pop(field_name, None)
    details = payload.get('details')
    if not isinstance(details, dict):
        raise SplunkIntegrationError(
            'Cannot delete an input without a details object'
        )
    for field_name in DETAIL_RESPONSE_FIELDS:
        details.pop(field_name, None)
    return payload


def create_integration(
    client: SplunkWebClient,
    config: RuntimeConfig,
    paths: ArtifactPaths,
    *,
    sleep: Callable[[float], None] = time.sleep,
    logger: Logger | None = None,
) -> None:
    """Create or update an input and write its template artifact."""
    log = logger or (lambda _message: None)
    request = _required_request(config)
    put_response = client.put_input(request)

    expected_version = None
    expected_update_time = None
    if input_uses_s3(request):
        if put_response is None or not s3_input_matches_request(
            put_response,
            request,
        ):
            raise SplunkIntegrationError(
                'Splunk returned an invalid S3 data input update response'
            )
        version = put_response['details'].get('version')
        update_time = put_response.get('lastUpdateTime')
        if version is None or not update_time:
            raise SplunkIntegrationError(
                'Splunk did not return a version and update time for '
                'the S3 data input update'
            )
        expected_version = str(version)
        expected_update_time = str(update_time)

    input_document = wait_for_input(
        client.get_input,
        request=request,
        expected_version=expected_version,
        expected_update_time=expected_update_time,
        sleep=sleep,
    )
    atomic_write(paths.input_json, _encode_json(input_document))
    ensure_hec_tokens(
        client,
        input_document,
        initial_delay_seconds=300,
        sleep=sleep,
        logger=log,
    )
    _write_template(client, paths)


def get_integration(
    client: SplunkWebClient,
    config: RuntimeConfig,
    paths: ArtifactPaths,
    *,
    sleep: Callable[[float], None] = time.sleep,
    logger: Logger | None = None,
) -> dict[str, str]:
    """Refresh an input and return the external-provider result."""
    request = _required_request(config)
    input_document = wait_for_input(
        client.get_input,
        request=request,
        sleep=sleep,
    )
    atomic_write(paths.input_json, _encode_json(input_document))
    ensure_hec_tokens(
        client,
        input_document,
        initial_delay_seconds=0,
        sleep=sleep,
        logger=logger,
    )
    raw_template = _write_template(client, paths)

    details = input_document['details']
    version = details.get('version')
    stack_name = details.get('stackName')
    if version is None or not isinstance(stack_name, str) or not stack_name:
        raise SplunkIntegrationError(
            'Splunk input response is missing version or stackName'
        )
    return {
        'version': str(version),
        'template_hash': hashlib.sha256(raw_template).hexdigest(),
        'stack_name': stack_name,
    }


def delete_integration(
    client: SplunkWebClient,
    paths: ArtifactPaths,
    *,
    logger: Logger | None = None,
) -> None:
    """Delete an input while preserving push-input HEC cleanup."""
    log = logger or (lambda _message: None)
    try:
        input_document = client.get_input()
    except SplunkHttpError as error:
        if error.status == 404:
            log('Splunk input is already absent; deletion is complete.')
            return
        raise

    atomic_write(paths.input_json, _encode_json(input_document))
    client.check_delete_readiness()
    client.put_input(build_delete_payload(input_document))
    client.check_delete_readiness()

    if not input_uses_s3(input_document):
        for category in PUSH_HEC_CLEANUP_CATEGORIES:
            client.delete_hec_token(category)

    client.check_delete_readiness()
    client.delete_input()


def _write_template(
    client: SplunkWebClient,
    paths: ArtifactPaths,
) -> bytes:
    raw_template = client.get_template()
    if not validate_cloudformation_template(raw_template):
        raise SplunkIntegrationError(
            'Splunk returned an invalid CloudFormation template'
        )
    atomic_write(paths.template_json, raw_template)
    return raw_template


def _required_request(config: RuntimeConfig) -> JsonObject:
    if config.input_request is None:
        raise SplunkIntegrationError(
            'The operation requires a Splunk input request'
        )
    if not validate_input_document(config.input_request):
        raise SplunkIntegrationError(
            'The configured Splunk data input request is invalid'
        )
    return config.input_request


def config_from_mapping(
    values: Mapping[str, str],
    *,
    require_request: bool,
) -> RuntimeConfig:
    """Parse Terraform environment or external-query values."""
    def required(name: str) -> str:
        value = values.get(name)
        if not isinstance(value, str) or not value:
            raise SplunkIntegrationError(
                f'Required runtime value {name} is missing'
            )
        return value

    input_request = None
    if require_request:
        raw_request = required('SPLUNK_CLOUD_INPUT_JSON')
        try:
            decoded_request = json.loads(raw_request)
        except json.JSONDecodeError as error:
            raise SplunkIntegrationError(
                'SPLUNK_CLOUD_INPUT_JSON is not valid JSON'
            ) from error
        if not isinstance(decoded_request, dict):
            raise SplunkIntegrationError(
                'SPLUNK_CLOUD_INPUT_JSON must contain a JSON object'
            )
        input_request = decoded_request

    return RuntimeConfig(
        cloud_url=required('SPLUNK_CLOUD'),
        input_id=required('SPLUNK_INPUT_UUID'),
        username=required('SPLUNK_CLOUD_USERNAME'),
        password=required('SPLUNK_CLOUD_PASSWORD'),
        input_request=input_request,
    )


def main(
    argv: Sequence[str] | None = None,
    *,
    environ: Mapping[str, str] | None = None,
    input_stream=None,
    output_stream=None,
    error_stream=None,
    artifact_dir: Path = Path('/tmp'),
) -> int:
    """Run one Terraform-facing lifecycle subcommand."""
    parser = argparse.ArgumentParser(
        description='Manage a Splunk Cloud Data Manager input.'
    )
    parser.add_argument('operation', choices=('create', 'get', 'delete'))
    arguments = parser.parse_args(argv)

    standard_input = sys.stdin if input_stream is None else input_stream
    standard_output = sys.stdout if output_stream is None else output_stream
    standard_error = sys.stderr if error_stream is None else error_stream
    logger = None

    try:
        if arguments.operation == 'get':
            query = json.load(standard_input)
            if not isinstance(query, dict):
                raise SplunkIntegrationError(
                    'The external-provider query must be a JSON object'
                )
            config = config_from_mapping(query, require_request=True)
        else:
            environment = os.environ if environ is None else environ
            config = config_from_mapping(
                environment,
                require_request=arguments.operation == 'create',
            )

        paths = ArtifactPaths.for_input(
            config.input_id,
            artifact_dir=artifact_dir,
        )
        logger = FileLogger(paths.log)
        client = SplunkWebClient(config, logger=logger)
        client.login()

        if arguments.operation == 'create':
            create_integration(client, config, paths, logger=logger)
        elif arguments.operation == 'get':
            result = get_integration(client, config, paths, logger=logger)
            print(
                json.dumps(result, separators=(',', ':')),
                file=standard_output,
                flush=True,
            )
        else:
            delete_integration(client, paths, logger=logger)
        return 0
    except Exception as error:
        if logger is not None:
            logger(
                f'Splunk Data Manager {arguments.operation} failed: {error}'
            )
        print(
            f'Splunk Data Manager {arguments.operation} failed: {error}',
            file=standard_error,
        )
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
