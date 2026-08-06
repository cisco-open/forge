#!/usr/bin/env python3.12
"""Read Splunk Data Manager values for Terraform external data sources."""

from __future__ import annotations

import http.cookiejar
import json
import sys
import urllib.error
import urllib.parse
import urllib.request
from collections.abc import Iterable, Mapping, Sequence
from typing import IO, Any

REQUEST_TIMEOUT_SECONDS = 30
LOGIN_COOKIE_NAMES = (
    'splunkweb_uid',
    'cval',
    'splunkweb_csrf_token_8443',
    'splunkd_8443',
    'AWSELB',
)
AUTHENTICATED_COOKIE_NAMES = (
    'splunkweb_csrf_token_8443',
    'splunkd_8443',
)
REQUIRED_AWS_CONFIG_NAMES = ('iamExternalId', 'instanceIamRole')
AJAX_HEADERS = {
    'Sec-Fetch-Dest': 'empty',
    'Sec-Fetch-Mode': 'cors',
    'Sec-Fetch-Site': 'same-origin',
    'X-Requested-With': 'XMLHttpRequest',
}


class ExternalDataError(RuntimeError):
    """A safe-to-report external data source failure."""


def _read_query(input_stream: IO[str]) -> dict[str, str]:
    try:
        query = json.load(input_stream)
    except json.JSONDecodeError as error:
        raise ExternalDataError('stdin must contain valid JSON') from error

    if not isinstance(query, dict):
        raise ExternalDataError('external data query must be a JSON object')
    if not all(
        isinstance(key, str) and isinstance(value, str)
        for key, value in query.items()
    ):
        raise ExternalDataError('external data query values must be strings')
    return query


def _required(query: Mapping[str, str], *names: str) -> tuple[str, ...]:
    missing = [name for name in names if not query.get(name)]
    if missing:
        raise ExternalDataError(
            f'external data query is missing: {", ".join(missing)}'
        )
    return tuple(query[name] for name in names)


def _cookie_values(cookies: Iterable[Any]) -> dict[str, str]:
    values: dict[str, str] = {}
    for cookie in cookies:
        if cookie.name in LOGIN_COOKIE_NAMES:
            values[cookie.name] = cookie.value
    return values


def _request_bytes(
    opener: Any,
    request: urllib.request.Request,
) -> bytes:
    with opener.open(request, timeout=REQUEST_TIMEOUT_SECONDS) as response:
        return response.read()


def authenticate(
    query: Mapping[str, str],
    *,
    opener: Any | None = None,
    cookie_jar: Any | None = None,
) -> dict[str, str]:
    """Authenticate to Splunk Cloud and return the legacy cookie result map."""
    splunk_cloud, username, password = _required(
        query,
        'splunk_cloud',
        'username',
        'password',
    )
    splunk_cloud = splunk_cloud.rstrip('/')

    if cookie_jar is None:
        cookie_jar = http.cookiejar.CookieJar()
    if opener is None:
        opener = urllib.request.build_opener(
            urllib.request.HTTPCookieProcessor(cookie_jar)
        )

    initial_login = urllib.request.Request(
        f'{splunk_cloud}/en-US/account/login?loginType=splunk',
        method='GET',
    )
    _request_bytes(opener, initial_login)

    initial_cookies = _cookie_values(cookie_jar)
    missing_initial = [
        name
        for name in ('splunkweb_uid', 'cval')
        if not initial_cookies.get(name)
    ]
    if missing_initial:
        raise ExternalDataError(
            'Splunk initial login did not return required cookies: '
            f'{", ".join(missing_initial)}'
        )

    login_form = urllib.parse.urlencode(
        {
            'cval': initial_cookies['cval'],
            'username': username,
            'password': password,
        }
    ).encode('utf-8')
    authenticated_login = urllib.request.Request(
        f'{splunk_cloud}/en-GB/account/login',
        data=login_form,
        headers={
            **AJAX_HEADERS,
            'Content-Type': 'application/x-www-form-urlencoded',
            'Cookie': (
                f'cval={initial_cookies["cval"]}; '
                f'splunkweb_uid={initial_cookies["splunkweb_uid"]}'
            ),
        },
        method='POST',
    )
    _request_bytes(opener, authenticated_login)

    authenticated_cookies = _cookie_values(cookie_jar)
    missing = [
        name
        for name in AUTHENTICATED_COOKIE_NAMES
        if not authenticated_cookies.get(name)
    ]
    if missing:
        raise ExternalDataError(
            'Splunk authenticated login did not return required cookies: '
            f'{", ".join(missing)}'
        )

    return {
        'splunkweb_uid': initial_cookies['splunkweb_uid'],
        'cval': initial_cookies['cval'],
        'splunkweb_csrf_token_8443': authenticated_cookies[
            'splunkweb_csrf_token_8443'
        ],
        'splunkd_8443': authenticated_cookies['splunkd_8443'],
        'awselb': authenticated_cookies.get('AWSELB', ''),
    }


def fetch_config(
    query: Mapping[str, str],
    *,
    opener: Any | None = None,
) -> dict[str, str]:
    """Return the legacy top-level ``aws`` configuration result map."""
    splunk_cloud, csrf_token, splunkd_cookie = _required(
        query,
        'splunk_cloud',
        'splunkweb_csrf_token_8443',
        'splunkd_8443',
    )
    awselb_cookie = query.get('awselb', '')
    splunk_cloud = splunk_cloud.rstrip('/')

    if opener is None:
        opener = urllib.request.build_opener()

    cookie_values = [
        f'splunkweb_csrf_token_8443={csrf_token}',
        f'splunk_csrf_token={csrf_token}',
        f'splunkd_8443={splunkd_cookie}',
    ]
    if awselb_cookie:
        cookie_values.append(f'AWSELB={awselb_cookie}')
    request = urllib.request.Request(
        f'{splunk_cloud}/en-US/splunkd/__raw/servicesNS/nobody/'
        'data_manager/cloudinput/globalconfig',
        headers={
            **AJAX_HEADERS,
            'Accept': 'application/json, text/plain, */*',
            'Cookie': '; '.join(cookie_values),
            'X-Splunk-Form-Key': csrf_token,
        },
        method='GET',
    )
    response_body = _request_bytes(opener, request)

    try:
        response = json.loads(response_body)
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ExternalDataError(
            'Splunk global configuration response was not valid JSON'
        ) from error

    aws_config = response.get('aws') if isinstance(response, dict) else None
    if not isinstance(aws_config, dict):
        raise ExternalDataError(
            'Splunk global configuration response is missing an aws object'
        )
    missing = [
        name
        for name in REQUIRED_AWS_CONFIG_NAMES
        if not isinstance(aws_config.get(name), str) or not aws_config[name]
    ]
    if missing:
        raise ExternalDataError(
            'Splunk aws configuration has missing or invalid required values: '
            f'{", ".join(missing)}'
        )
    return {name: aws_config[name] for name in REQUIRED_AWS_CONFIG_NAMES}


def main(
    argv: Sequence[str] | None = None,
    *,
    input_stream: IO[str] | None = None,
    output_stream: IO[str] | None = None,
    error_stream: IO[str] | None = None,
) -> int:
    """Run one Terraform external data source operation."""
    if argv is None:
        argv = sys.argv[1:]
    if input_stream is None:
        input_stream = sys.stdin
    if output_stream is None:
        output_stream = sys.stdout
    if error_stream is None:
        error_stream = sys.stderr

    if len(argv) != 1 or argv[0] not in {'authenticate', 'config'}:
        print(
            f'Usage: {sys.argv[0]} authenticate|config',
            file=error_stream,
        )
        return 2

    try:
        query = _read_query(input_stream)
        if argv[0] == 'authenticate':
            result = authenticate(query)
        else:
            result = fetch_config(query)
    except (ExternalDataError, urllib.error.URLError) as error:
        print(f'error: {error}', file=error_stream)
        return 1

    json.dump(result, output_stream, separators=(',', ':'), sort_keys=True)
    output_stream.write('\n')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
