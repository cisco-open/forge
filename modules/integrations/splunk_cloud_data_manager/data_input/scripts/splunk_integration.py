#!/usr/bin/env python3
"""Manage one Splunk Cloud Data Manager input for Terraform."""

from __future__ import annotations

import argparse
import copy
import hashlib
import http.cookiejar
import json
import os
import re
import sys
import time
from collections.abc import Callable, Mapping, Sequence
from dataclasses import dataclass, field
from html import unescape
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import quote, quote_plus, unquote, urlencode
from urllib.request import HTTPCookieProcessor, Request, build_opener

JsonObject = dict[str, Any]
Logger = Callable[[str], None]

REDACTED = '[REDACTED]'
HTTP_ERROR_BODY_LIMIT = 16384
REQUEST_PAYLOAD_LIMIT = 16384
SENSITIVE_FIELD_FRAGMENTS = (
    'accesskey',
    'apikey',
    'authorization',
    'cookie',
    'credential',
    'csrf',
    'externalid',
    'passwd',
    'password',
    'privatekey',
    'secret',
    'sessionkey',
    'splunkd8443',
    'splunkwebuid',
    'token',
    'xsplunkformkey',
)
SENSITIVE_ASSIGNMENT = re.compile(
    r'(?i)((?:"|\')?(?:access[_-]?key|api[_-]?(?:key|token)|'
    r'authorization|cookie|credential|csrf|external[_-]?id|'
    r'passw(?:or)?d|private[_-]?key|secret|session[_-]?(?:key|token)|'
    r'token|username|x-splunk-form-key)(?:"|\')?\s*[:=]\s*)'
    r'(?:(?:"(?:\\.|[^"\r\n])*"?)|'
    r'(?:\'(?:\\.|[^\'\r\n])*\'?)|[^\r\n&;<>{},]+)'
)

NOAH_TOKEN_PENDING = 'Noah stack token creation in progress'

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
    """Raised when a Splunk lifecycle operation cannot continue."""


class SplunkHttpError(SplunkIntegrationError):
    """Raised for an unsuccessful Splunk HTTP request."""

    def __init__(
        self,
        status: int,
        message: str,
        response_body: str | None = None,
    ):
        super().__init__(message)
        self.status = status
        self.response_body = response_body


@dataclass(frozen=True, slots=True)
class RuntimeConfig:
    """Runtime values supplied by Terraform."""

    cloud_url: str
    input_id: str
    username: str = field(repr=False)
    password: str = field(repr=False)
    input_request: JsonObject | None = field(default=None, repr=False)


def encode_json(payload: JsonObject) -> bytes:
    """Encode a compact JSON object."""
    return json.dumps(payload, separators=(',', ':')).encode('utf-8')


def decode_json(raw: bytes, description: str) -> JsonObject:
    """Decode a Splunk response and require a JSON object."""
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


def _normalized_field_name(value: object) -> str:
    return ''.join(
        character
        for character in str(value).casefold()
        if character.isalnum()
    )


def _is_sensitive_field_name(value: object) -> bool:
    normalized = _normalized_field_name(value)
    return any(
        fragment in normalized
        for fragment in SENSITIVE_FIELD_FRAGMENTS
    )


def redact_sensitive_fields(value: Any) -> Any:
    """Return a copy with credential-like fields redacted."""
    if isinstance(value, Mapping):
        tag_name = next(
            (
                item
                for key, item in value.items()
                if _normalized_field_name(key) == 'key'
            ),
            None,
        )
        sensitive_tag = isinstance(
            tag_name,
            str,
        ) and _is_sensitive_field_name(tag_name)
        redacted = {}
        for key, item in value.items():
            normalized_key = _normalized_field_name(key)
            if _is_sensitive_field_name(key) or (
                sensitive_tag and normalized_key == 'value'
            ):
                redacted[key] = REDACTED
            else:
                redacted[key] = redact_sensitive_fields(item)
        return redacted
    if isinstance(value, list):
        return [redact_sensitive_fields(item) for item in value]
    if isinstance(value, tuple):
        return tuple(redact_sensitive_fields(item) for item in value)
    if isinstance(value, str):
        return SENSITIVE_ASSIGNMENT.sub(
            lambda match: f'{match.group(1)}{REDACTED}',
            value,
        )
    return value


def redact_known_secrets(
    value: Any,
    secret_values: Sequence[str],
) -> Any:
    """Return a copy with known credential values redacted."""
    if isinstance(value, Mapping):
        return {
            key: redact_known_secrets(item, secret_values)
            for key, item in value.items()
        }
    if isinstance(value, list):
        return [
            redact_known_secrets(item, secret_values)
            for item in value
        ]
    if isinstance(value, tuple):
        return tuple(
            redact_known_secrets(item, secret_values)
            for item in value
        )
    if isinstance(value, str):
        value = unescape(unquote(value))
        for secret in secret_values:
            value = value.replace(secret, REDACTED)
    return value


def known_secret_variants(secret_values: Sequence[str]) -> tuple[str, ...]:
    """Return common transport encodings for known credentials."""
    variants = set()
    for secret in secret_values:
        if not secret:
            continue
        variants.update(
            {
                secret,
                quote(secret, safe=''),
                quote_plus(secret, safe=''),
                json.dumps(secret)[1:-1],
            }
        )
    return tuple(sorted(variants, key=len, reverse=True))


def render_diagnostic(
    value: Any,
    *,
    secret_values: Sequence[str] = (),
    limit: int,
) -> str:
    """Render one bounded JSON diagnostic without known secrets."""
    known_secrets = known_secret_variants(secret_values)
    redacted = redact_known_secrets(value, known_secrets)
    redacted = redact_sensitive_fields(redacted)
    rendered = json.dumps(
        redacted,
        separators=(',', ':'),
        sort_keys=True,
    )
    if len(rendered) > limit:
        return (
            f'{rendered[:limit]}...'
            f'[truncated; total_chars={len(rendered)}]'
        )
    return rendered


def render_http_error_body(
    raw: bytes,
    *,
    secret_values: Sequence[str] = (),
) -> str:
    """Render a bounded HTTP response body for failure diagnostics."""
    if not raw:
        return '<empty>'
    try:
        value = json.loads(raw)
    except (UnicodeDecodeError, json.JSONDecodeError):
        value = unescape(unquote(raw.decode('utf-8', errors='replace')))
    return render_diagnostic(
        value,
        secret_values=secret_values,
        limit=HTTP_ERROR_BODY_LIMIT,
    )


class SplunkWebClient:
    """Authenticated in-memory Splunk Web session."""

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
        cookies: http.cookiejar.CookieJar | None = None,
        opener=None,
        logger: Logger | None = None,
    ):
        self.config = config
        self.cloud_url = config.cloud_url.rstrip('/')
        self.cookies = (
            cookies if cookies is not None else http.cookiejar.CookieJar()
        )
        self.opener = opener or build_opener(
            HTTPCookieProcessor(self.cookies)
        )
        self.logger = logger or (lambda _message: None)
        self._csrf_token: str | None = None
        self._cookie_header: str | None = None

    @property
    def input_path(self) -> str:
        """Return the Data Manager input API path."""
        return (
            '/en-GB/splunkd/__raw/servicesNS/nobody/'
            f'data_manager/cloudinput/inputs/{self.config.input_id}'
        )

    def login(self) -> None:
        """Perform the established two-step Splunk Web login."""
        self._send('GET', '/en-US/account/login?loginType=splunk')
        cval = self._cookie('cval')
        splunkweb_uid = self._cookie('splunkweb_uid')
        login_body = urlencode(
            {
                'cval': cval,
                'username': self.config.username,
                'password': self.config.password,
            }
        ).encode('utf-8')

        self._send(
            'POST',
            '/en-GB/account/login',
            headers={
                **self._browser_headers,
                'Content-Type': 'application/x-www-form-urlencoded',
                'Cookie': f'cval={cval}; splunkweb_uid={splunkweb_uid}',
            },
            body=login_body,
        )

        csrf_token = self._cookie('splunkweb_csrf_token_8443')
        self._csrf_token = csrf_token
        cookie_values = [
            f'splunkweb_csrf_token_8443={csrf_token}',
            f'splunk_csrf_token={csrf_token}',
            f'splunkd_8443={self._cookie("splunkd_8443")}',
        ]
        awselb = self._optional_cookie('AWSELB')
        if awselb is not None:
            cookie_values.append(f'AWSELB={awselb}')
        self._cookie_header = '; '.join(cookie_values)

    def put_input(self, payload: JsonObject) -> None:
        """Create or update the configured input."""
        self.request(
            'PUT',
            self.input_path,
            content_type='application/json',
            body=encode_json(payload),
        )

    def get_input(self) -> JsonObject:
        """Fetch the current input document."""
        raw = self.request(
            'GET',
            self.input_path,
            content_type='text/plain',
        )
        return decode_json(raw, 'input response')

    def get_hec_token(self, category: str) -> JsonObject:
        """Fetch HEC token status for a push dataset."""
        query = urlencode({'dataset': category})
        try:
            raw = self.request(
                'GET',
                (
                    '/en-US/splunkd/__raw/servicesNS/nobody/'
                    'data_manager/cloudinput/inputs/'
                    f'{self.config.input_id}/hectoken?{query}'
                ),
                content_type='application/json',
            )
            return decode_json(raw, 'HEC token response')
        except SplunkIntegrationError:
            return {}

    def delete_hec_token(self, category: str) -> None:
        """Delete one push-dataset HEC token."""
        query = urlencode({'dataset': category})
        try:
            self.request(
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
        """Download the input CloudFormation template."""
        return self.request(
            'GET',
            f'{self.input_path}/templates/dataaccount/ingest',
            content_type='text/plain',
        )

    def check_delete_readiness(self) -> None:
        """Ask Splunk whether the input may be deleted."""
        self.request(
            'GET',
            f'{self.input_path}/validate/checkdeletereadiness',
            content_type='application/json',
        )

    def delete_input(self) -> None:
        """Delete the Data Manager input."""
        try:
            self.request(
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

    def request(
        self,
        method: str,
        path: str,
        *,
        content_type: str,
        body: bytes | None = None,
    ) -> bytes:
        """Send one authenticated API request."""
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
    ) -> bytes:
        request = Request(
            f'{self.cloud_url}{path}',
            data=body,
            headers=dict(headers or {}),
            method=method,
        )
        try:
            with self.opener.open(request) as response:
                status = response.status
                raw = response.read()
        except HTTPError as error:
            status = error.code
            raw = error.read()
        except URLError as error:
            raise SplunkHttpError(
                0,
                f'{method} request to Splunk failed at the transport layer',
            ) from error

        self.logger(f'{method} {path} returned HTTP {status}.')
        if not 200 <= status < 300:
            secret_values = (
                self.config.username,
                self.config.password,
                self._csrf_token or '',
                *(cookie.value for cookie in self.cookies),
            )
            response_body = None
            if '/data_manager/' in path:
                response_body = render_http_error_body(
                    raw,
                    secret_values=secret_values,
                )
            raise SplunkHttpError(
                status,
                f'{method} {path} returned HTTP {status}',
                response_body,
            )
        return raw

    def _cookie(self, name: str) -> str:
        value = self._optional_cookie(name)
        if value is None:
            raise SplunkIntegrationError(
                f'Splunk login did not return the required {name} cookie'
            )
        return value

    def _optional_cookie(self, name: str) -> str | None:
        values = [
            cookie.value
            for cookie in self.cookies
            if cookie.name == name
        ]
        return values[-1] if values else None


def validate_input_document(document: object) -> bool:
    """Return whether an input has a datasetInfo object."""
    if not isinstance(document, dict):
        return False
    details = document.get('details')
    return isinstance(details, dict) and isinstance(
        details.get('datasetInfo'),
        dict,
    )


def fetch_input(fetch: Callable[[], JsonObject]) -> JsonObject:
    """Fetch one valid Data Manager input document."""
    document = fetch()
    if not validate_input_document(document):
        raise SplunkIntegrationError(
            'Splunk returned an invalid data input response'
        )
    return document


def validate_cloudformation_template(raw_template: bytes) -> bool:
    """Require a JSON template with non-empty Resources."""
    try:
        template = json.loads(raw_template)
    except (UnicodeDecodeError, json.JSONDecodeError):
        return False
    if not isinstance(template, dict):
        return False
    resources = template.get('Resources')
    return isinstance(resources, dict) and bool(resources)


def dataset_hec_categories(
    document: JsonObject,
) -> list[tuple[str, str]]:
    """Map push dataset names to established HEC categories."""
    if not validate_input_document(document):
        raise SplunkIntegrationError(
            'Cannot map HEC categories from an invalid input'
        )
    return [
        (dataset, DATASET_HEC_CATEGORIES[dataset])
        for dataset in sorted(document['details']['datasetInfo'])
        if dataset in DATASET_HEC_CATEGORIES
    ]


def ensure_hec_tokens(
    client,
    document: JsonObject,
    *,
    initial_delay_seconds: int,
    sleep: Callable[[float], None] = time.sleep,
    logger: Logger | None = None,
) -> None:
    """Wait for each push-input HEC token."""
    log = logger or (lambda _message: None)
    categories = dataset_hec_categories(document)
    if categories and initial_delay_seconds:
        log(
            'Waiting '
            f'{initial_delay_seconds} seconds for HEC token provisioning.'
        )
        sleep(initial_delay_seconds)

    for dataset, category in categories:
        while True:
            token_response = client.get_hec_token(category)
            if token_response.get('details') == NOAH_TOKEN_PENDING:
                log(f'HEC token creation is still in progress for {category}.')
                sleep(60)
                continue
            if token_response.get('token'):
                log(f'HEC token exists for {category}.')
            else:
                log(f'Ignoring unexpected HEC response for {dataset}.')
            break


def build_delete_payload(
    document: JsonObject,
    *,
    mode: str = 'MarkedForDelete',
) -> JsonObject:
    """Remove response-owned fields before setting deletion mode."""
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
    client,
    request: JsonObject,
    template_path: Path,
    *,
    sleep: Callable[[float], None] = time.sleep,
    logger: Logger | None = None,
) -> None:
    """Create or update an input and write its template."""
    _require_valid_request(request)
    client.put_input(request)
    input_document = fetch_input(client.get_input)
    ensure_hec_tokens(
        client,
        input_document,
        initial_delay_seconds=300,
        sleep=sleep,
        logger=logger,
    )
    _write_template(client, template_path)


def get_integration(
    client,
    template_path: Path,
    *,
    sleep: Callable[[float], None] = time.sleep,
    logger: Logger | None = None,
) -> dict[str, str]:
    """Refresh an input and return the Terraform external result."""
    input_document = fetch_input(client.get_input)
    ensure_hec_tokens(
        client,
        input_document,
        initial_delay_seconds=0,
        sleep=sleep,
        logger=logger,
    )
    raw_template = _write_template(client, template_path)

    details = input_document['details']
    version = details.get('version')
    if version is None:
        raise SplunkIntegrationError(
            'Splunk input response is missing version'
        )
    return {
        'version': str(version),
        'template_hash': hashlib.sha256(raw_template).hexdigest(),
    }


def delete_integration(
    client,
    *,
    logger: Logger | None = None,
) -> None:
    """Delete an input and clean up push-input HEC tokens."""
    log = logger or (lambda _message: None)
    try:
        input_document = client.get_input()
    except SplunkHttpError as error:
        if error.status == 404:
            log('Splunk input is already absent; deletion is complete.')
            return
        raise

    client.check_delete_readiness()
    client.put_input(build_delete_payload(input_document))
    client.check_delete_readiness()

    if dataset_hec_categories(input_document):
        for category in PUSH_HEC_CLEANUP_CATEGORIES:
            client.delete_hec_token(category)

    client.check_delete_readiness()
    client.delete_input()


def _write_template(client, template_path: Path) -> bytes:
    raw_template = client.get_template()
    if not validate_cloudformation_template(raw_template):
        raise SplunkIntegrationError(
            'Splunk returned an invalid CloudFormation template'
        )
    template_path.parent.mkdir(parents=True, exist_ok=True)
    template_path.write_bytes(raw_template)
    return raw_template


def _require_valid_request(request: object) -> None:
    if not validate_input_document(request):
        raise SplunkIntegrationError(
            'The configured Splunk data input request is invalid'
        )


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
        try:
            input_request = json.loads(required('SPLUNK_CLOUD_INPUT_JSON'))
        except json.JSONDecodeError as error:
            raise SplunkIntegrationError(
                'SPLUNK_CLOUD_INPUT_JSON is not valid JSON'
            ) from error
        if not isinstance(input_request, dict):
            raise SplunkIntegrationError(
                'SPLUNK_CLOUD_INPUT_JSON must contain a JSON object'
            )

    return RuntimeConfig(
        cloud_url=required('SPLUNK_CLOUD'),
        input_id=required('SPLUNK_INPUT_UUID'),
        username=required('SPLUNK_CLOUD_USERNAME'),
        password=required('SPLUNK_CLOUD_PASSWORD'),
        input_request=input_request,
    )


def _parse_operation(argv: Sequence[str] | None) -> str:
    parser = argparse.ArgumentParser(
        description='Manage a Splunk Cloud Data Manager input.'
    )
    parser.add_argument('operation', choices=('create', 'get', 'delete'))
    return parser.parse_args(argv).operation


def main(
    argv: Sequence[str] | None = None,
    *,
    environ: Mapping[str, str] | None = None,
    input_stream=None,
    output_stream=None,
    error_stream=None,
    artifact_dir: Path = Path('/tmp'),
) -> int:
    """Run one Terraform-facing lifecycle operation."""
    operation = _parse_operation(argv)
    environment = os.environ if environ is None else environ
    standard_input = sys.stdin if input_stream is None else input_stream
    standard_output = sys.stdout if output_stream is None else output_stream
    standard_error = sys.stderr if error_stream is None else error_stream
    messages: list[str] = []
    credential_values: tuple[str, ...] = ()
    config: RuntimeConfig | None = None

    def sanitize(message: str) -> str:
        for value in credential_values:
            message = message.replace(value, '[REDACTED]')
        return message

    def log(message: str) -> None:
        message = sanitize(message)
        if operation == 'get':
            messages.append(message)
            return
        print(message, file=standard_error, flush=True)

    try:
        values = environment
        if operation == 'get':
            values = json.load(standard_input)
            if not isinstance(values, dict):
                raise SplunkIntegrationError(
                    'The external-provider query must be a JSON object'
                )
        config = config_from_mapping(
            values,
            require_request=operation == 'create',
        )
        credential_values = tuple(
            sorted(
                {config.username, config.password},
                key=len,
                reverse=True,
            )
        )
        client = SplunkWebClient(config, logger=log)
        client.login()
        template_path = artifact_dir / f'{config.input_id}_template.json'

        if operation == 'create':
            create_integration(
                client,
                config.input_request,
                template_path,
                logger=log,
            )
        elif operation == 'get':
            result = get_integration(
                client,
                template_path,
                logger=log,
            )
            print(
                json.dumps(result, separators=(',', ':')),
                file=standard_output,
                flush=True,
            )
        else:
            delete_integration(client, logger=log)
        return 0
    except Exception as error:
        if operation == 'get':
            for message in messages:
                print(message, file=standard_error)
        print(
            'Splunk Data Manager '
            f'{operation} failed: {sanitize(str(error))}',
            file=standard_error,
        )
        if isinstance(
            error,
            SplunkHttpError,
        ) and error.response_body is not None:
            print(
                'Splunk HTTP response body: '
                f'{sanitize(error.response_body)}',
                file=standard_error,
            )
        if config is not None and config.input_request is not None:
            request_payload = render_diagnostic(
                config.input_request,
                secret_values=credential_values,
                limit=REQUEST_PAYLOAD_LIMIT,
            )
            print(
                'Splunk Data Manager request payload (redacted): '
                f'{request_payload}',
                file=standard_error,
            )
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
