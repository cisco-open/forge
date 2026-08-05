"""Small authenticated client for the Splunk Data Manager API."""

from __future__ import annotations

import http.cookiejar
import json
from collections.abc import Callable, Mapping
from dataclasses import dataclass, field
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import HTTPCookieProcessor, Request, build_opener

JsonObject = dict[str, Any]
Logger = Callable[[str], None]


class SplunkIntegrationError(RuntimeError):
    """Raised when a Splunk lifecycle operation cannot continue."""


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
        """Send one request and retain HTTP errors for classification."""
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
        """Return the most recently stored cookie with the given name."""
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
            body=encode_json(payload),
        )
        if not response.body:
            return None
        try:
            return decode_json(response.body, 'input update response')
        except SplunkIntegrationError:
            return None

    def get_input(self) -> JsonObject:
        """Fetch the current Data Manager input document."""
        response = self._api_request(
            'GET',
            self.input_path,
            content_type='text/plain',
        )
        return decode_json(response.body, 'input response')

    def get_hec_token(self, category: str) -> JsonObject:
        """Fetch HEC token status for a push-based dataset."""
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
            return decode_json(response.body, 'HEC token response')
        except SplunkIntegrationError:
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
        """Ask Splunk whether the input may be deleted."""
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
