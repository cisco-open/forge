"""Hermetic tests for the Splunk Data Manager external-data helper."""

from __future__ import annotations

import http.cookiejar
import importlib.util
import io
import json
import sys
import urllib.parse
from pathlib import Path
from types import ModuleType, SimpleNamespace
from unittest.mock import patch

import pytest

pytestmark = pytest.mark.contract

REPO_ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = REPO_ROOT / (
    'modules/integrations/splunk_cloud_data_manager_common'
)
SCRIPT_PATH = MODULE_PATH / 'scripts/splunk_data_manager.py'
TERRAFORM_PATH = MODULE_PATH / 'splunk.tf'


def load_helper() -> ModuleType:
    spec = importlib.util.spec_from_file_location(
        'splunk_data_manager_external',
        SCRIPT_PATH,
    )
    assert spec is not None
    assert spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


class FakeResponse(io.BytesIO):
    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        self.close()
        return False


class RecordingOpener:
    def __init__(self, responses, callbacks=None):
        self.responses = list(responses)
        self.callbacks = list(callbacks or [])
        self.requests = []
        self.timeouts = []

    def open(self, request, timeout):
        self.requests.append(request)
        self.timeouts.append(timeout)
        index = len(self.requests) - 1
        if index < len(self.callbacks):
            self.callbacks[index]()
        response = self.responses[index]
        if isinstance(response, BaseException):
            raise response
        return FakeResponse(response)


def add_cookies(cookie_jar, **cookies):
    cookie_jar.extend(
        SimpleNamespace(name=name, value=value)
        for name, value in cookies.items()
    )


def add_real_cookies(
    cookie_jar: http.cookiejar.CookieJar,
    **cookies: str,
) -> None:
    for name, value in cookies.items():
        cookie_jar.set_cookie(
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


def authentication_query() -> dict[str, str]:
    return {
        'splunk_cloud': 'https://splunk.example.com/',
        'username': 'test-user',
        'password': 'test-password',
    }


def config_query(*, awselb: str = 'awselb-value') -> dict[str, str]:
    return {
        'splunk_cloud': 'https://splunk.example.com',
        'splunkweb_csrf_token_8443': 'csrf-value',
        'splunkd_8443': 'splunkd-value',
        'awselb': awselb,
    }


def valid_config_response() -> bytes:
    return json.dumps(
        {
            'aws': {
                'iamExternalId': 'external-id-123',
                'instanceIamRole': (
                    'arn:aws:iam::999999999999:role/splunk-dm'
                ),
                'unusedNested': {'retries': 3},
            },
            'ignored': 'value',
        }
    ).encode('utf-8')


def test_authenticate_preserves_the_external_cookie_contract() -> None:
    helper = load_helper()
    cookie_jar = []
    opener = RecordingOpener(
        [b'initial login', b'authenticated'],
        callbacks=[
            lambda: add_cookies(
                cookie_jar,
                splunkweb_uid='uid-value',
                cval='cval-value',
            ),
            lambda: add_cookies(
                cookie_jar,
                splunkweb_csrf_token_8443='csrf-value',
                splunkd_8443='splunkd-value',
                AWSELB='awselb-value',
            ),
        ],
    )

    with patch('builtins.open', side_effect=AssertionError('no file access')):
        result = helper.authenticate(
            authentication_query(),
            opener=opener,
            cookie_jar=cookie_jar,
        )

    assert result == {
        'splunkweb_uid': 'uid-value',
        'cval': 'cval-value',
        'splunkweb_csrf_token_8443': 'csrf-value',
        'splunkd_8443': 'splunkd-value',
        'awselb': 'awselb-value',
    }
    initial_request, authenticated_request = opener.requests
    assert initial_request.full_url == (
        'https://splunk.example.com/en-US/account/login?loginType=splunk'
    )
    assert initial_request.get_method() == 'GET'
    assert authenticated_request.full_url == (
        'https://splunk.example.com/en-GB/account/login'
    )
    assert authenticated_request.get_method() == 'POST'
    assert authenticated_request.get_header('Cookie') == (
        'cval=cval-value; splunkweb_uid=uid-value'
    )
    assert urllib.parse.parse_qs(
        authenticated_request.data.decode('utf-8')
    ) == {
        'cval': ['cval-value'],
        'username': ['test-user'],
        'password': ['test-password'],
    }
    authenticated_headers = {
        name.lower(): value
        for name, value in authenticated_request.header_items()
    }
    assert authenticated_headers['sec-fetch-dest'] == 'empty'
    assert authenticated_headers['sec-fetch-mode'] == 'cors'
    assert authenticated_headers['sec-fetch-site'] == 'same-origin'
    assert authenticated_headers['x-requested-with'] == 'XMLHttpRequest'
    assert authenticated_headers['content-type'] == (
        'application/x-www-form-urlencoded'
    )
    assert opener.timeouts == [30, 30]


def test_authenticate_builds_an_in_memory_cookie_aware_opener(
    monkeypatch,
) -> None:
    helper = load_helper()
    captured = {}

    def fake_build_opener(handler):
        assert isinstance(handler, helper.urllib.request.HTTPCookieProcessor)
        captured['cookie_jar'] = handler.cookiejar
        return RecordingOpener(
            [b'initial login', b'authenticated'],
            callbacks=[
                lambda: add_real_cookies(
                    handler.cookiejar,
                    splunkweb_uid='uid-value',
                    cval='cval-value',
                ),
                lambda: add_real_cookies(
                    handler.cookiejar,
                    splunkweb_csrf_token_8443='csrf-value',
                    splunkd_8443='splunkd-value',
                ),
            ],
        )

    monkeypatch.setattr(
        helper.urllib.request,
        'build_opener',
        fake_build_opener,
    )

    result = helper.authenticate(authentication_query())

    assert isinstance(captured['cookie_jar'], http.cookiejar.CookieJar)
    assert result['splunkweb_csrf_token_8443'] == 'csrf-value'
    assert result['awselb'] == ''


def test_authenticate_preserves_initial_cookies_when_login_clears_them() -> None:
    helper = load_helper()
    cookie_jar = []

    def replace_initial_cookies() -> None:
        cookie_jar.clear()
        add_cookies(
            cookie_jar,
            splunkweb_csrf_token_8443='csrf-value',
            splunkd_8443='splunkd-value',
        )

    opener = RecordingOpener(
        [b'initial login', b'authenticated'],
        callbacks=[
            lambda: add_cookies(
                cookie_jar,
                splunkweb_uid='initial-uid',
                cval='initial-cval',
            ),
            replace_initial_cookies,
        ],
    )

    result = helper.authenticate(
        authentication_query(),
        opener=opener,
        cookie_jar=cookie_jar,
    )

    assert result['splunkweb_uid'] == 'initial-uid'
    assert result['cval'] == 'initial-cval'
    assert result['splunkweb_csrf_token_8443'] == 'csrf-value'


@pytest.mark.parametrize(
    ('cookies', 'missing_name'),
    [
        ({'cval': 'cval-value'}, 'splunkweb_uid'),
        ({'splunkweb_uid': 'uid-value'}, 'cval'),
    ],
)
def test_authenticate_rejects_incomplete_initial_cookies(
    cookies: dict[str, str],
    missing_name: str,
) -> None:
    helper = load_helper()
    cookie_jar = []
    opener = RecordingOpener(
        [b'initial login'],
        callbacks=[lambda: add_cookies(cookie_jar, **cookies)],
    )

    with pytest.raises(helper.ExternalDataError, match=missing_name):
        helper.authenticate(
            authentication_query(),
            opener=opener,
            cookie_jar=cookie_jar,
        )


@pytest.mark.parametrize(
    ('cookies', 'missing_name'),
    [
        ({'splunkd_8443': 'splunkd-value'}, 'splunkweb_csrf_token_8443'),
        (
            {'splunkweb_csrf_token_8443': 'csrf-value'},
            'splunkd_8443',
        ),
    ],
)
def test_authenticate_rejects_incomplete_authenticated_cookies(
    cookies: dict[str, str],
    missing_name: str,
) -> None:
    helper = load_helper()
    cookie_jar = []
    opener = RecordingOpener(
        [b'initial login', b'authenticated'],
        callbacks=[
            lambda: add_cookies(
                cookie_jar,
                splunkweb_uid='uid-value',
                cval='cval-value',
            ),
            lambda: add_cookies(cookie_jar, **cookies),
        ],
    )

    with pytest.raises(helper.ExternalDataError, match=missing_name):
        helper.authenticate(
            authentication_query(),
            opener=opener,
            cookie_jar=cookie_jar,
        )


def test_fetch_config_returns_only_the_required_aws_values() -> None:
    helper = load_helper()
    opener = RecordingOpener([valid_config_response()])

    result = helper.fetch_config(config_query(), opener=opener)

    assert result == {
        'iamExternalId': 'external-id-123',
        'instanceIamRole': 'arn:aws:iam::999999999999:role/splunk-dm',
    }
    request = opener.requests[0]
    assert request.full_url.endswith(
        '/en-US/splunkd/__raw/servicesNS/nobody/'
        'data_manager/cloudinput/globalconfig'
    )
    assert request.get_method() == 'GET'
    assert request.get_header('Cookie') == (
        'splunkweb_csrf_token_8443=csrf-value; '
        'splunk_csrf_token=csrf-value; '
        'splunkd_8443=splunkd-value; '
        'AWSELB=awselb-value'
    )
    assert request.get_header('X-splunk-form-key') == 'csrf-value'
    config_headers = {
        name.lower(): value for name, value in request.header_items()
    }
    assert config_headers['accept'] == 'application/json, text/plain, */*'
    assert config_headers['sec-fetch-dest'] == 'empty'
    assert config_headers['sec-fetch-mode'] == 'cors'
    assert config_headers['sec-fetch-site'] == 'same-origin'
    assert config_headers['x-requested-with'] == 'XMLHttpRequest'
    assert opener.timeouts == [30]


def test_fetch_config_omits_an_empty_optional_awselb_cookie() -> None:
    helper = load_helper()
    opener = RecordingOpener([valid_config_response()])

    helper.fetch_config(config_query(awselb=''), opener=opener)

    assert opener.requests[0].get_header('Cookie') == (
        'splunkweb_csrf_token_8443=csrf-value; '
        'splunk_csrf_token=csrf-value; '
        'splunkd_8443=splunkd-value'
    )


@pytest.mark.parametrize('body', [b'', b'  \n', b'not-json'])
def test_fetch_config_rejects_a_non_json_response(body: bytes) -> None:
    helper = load_helper()

    with pytest.raises(
        helper.ExternalDataError,
        match='global configuration response was not valid JSON',
    ):
        helper.fetch_config(
            config_query(),
            opener=RecordingOpener([body]),
        )


@pytest.mark.parametrize(
    ('body', 'message'),
    [
        (b'[]', 'missing an aws object'),
        (b'{"not_aws": {}}', 'missing an aws object'),
    ],
)
def test_fetch_config_rejects_an_invalid_external_result(
    body: bytes,
    message: str,
) -> None:
    helper = load_helper()

    with pytest.raises(helper.ExternalDataError, match=message):
        helper.fetch_config(
            config_query(),
            opener=RecordingOpener([body]),
        )


@pytest.mark.parametrize(
    ('aws_config', 'missing_names'),
    [
        ({}, 'iamExternalId, instanceIamRole'),
        ({'iamExternalId': 'id'}, 'instanceIamRole'),
        ({'instanceIamRole': 'role'}, 'iamExternalId'),
        (
            {'iamExternalId': 'id', 'instanceIamRole': 3},
            'instanceIamRole',
        ),
        (
            {'iamExternalId': '', 'instanceIamRole': ''},
            'iamExternalId, instanceIamRole',
        ),
    ],
)
def test_fetch_config_requires_non_empty_iam_values(
    aws_config: dict[str, object],
    missing_names: str,
) -> None:
    helper = load_helper()
    body = json.dumps({'aws': aws_config}).encode('utf-8')

    with pytest.raises(
        helper.ExternalDataError,
        match=f'missing or invalid required values: {missing_names}',
    ):
        helper.fetch_config(
            config_query(),
            opener=RecordingOpener([body]),
        )


def test_main_writes_compact_external_json(monkeypatch) -> None:
    helper = load_helper()
    output = io.StringIO()
    monkeypatch.setattr(
        helper,
        'fetch_config',
        lambda query: {'instanceIamRole': 'role', 'iamExternalId': 'id'},
    )

    return_code = helper.main(
        ['config'],
        input_stream=io.StringIO(json.dumps(config_query())),
        output_stream=output,
        error_stream=io.StringIO(),
    )

    assert return_code == 0
    assert output.getvalue() == (
        '{"iamExternalId":"id","instanceIamRole":"role"}\n'
    )


def test_main_reports_an_empty_config_response_without_secrets(
    monkeypatch,
) -> None:
    helper = load_helper()
    output = io.StringIO()
    error = io.StringIO()
    query = config_query()
    monkeypatch.setattr(
        helper.urllib.request,
        'build_opener',
        lambda: RecordingOpener([b'']),
    )

    return_code = helper.main(
        ['config'],
        input_stream=io.StringIO(json.dumps(query)),
        output_stream=output,
        error_stream=error,
    )

    assert return_code == 1
    assert output.getvalue() == ''
    assert error.getvalue() == (
        'error: Splunk global configuration response was not valid JSON\n'
    )
    assert all(value not in error.getvalue() for value in query.values())


def test_terraform_uses_python_and_stdin_queries_for_both_sources() -> None:
    terraform_source = TERRAFORM_PATH.read_text(encoding='utf-8')

    assert terraform_source.count('scripts/splunk_data_manager.py') == 2
    assert terraform_source.count('"python3.12"') == 2
    assert '"authenticate"' in terraform_source
    assert '"config"' in terraform_source
    assert 'username     = local.splunk_cloud_username' in terraform_source
    assert 'password     = local.splunk_cloud_password' in terraform_source
    assert '"bash", "-c"' not in terraform_source
    assert '/tmp/cookies' not in terraform_source
    assert 'curl ' not in terraform_source
    assert 'jq ' not in terraform_source
