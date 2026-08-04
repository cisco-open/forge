"""Hermetic tests for the Splunk Data Manager external data helper."""

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
        return FakeResponse(self.responses[index])


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
            {
                'splunk_cloud': 'https://splunk.example.com/',
                'username': 'test-user',
                'password': 'test-password',
            },
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
    assert len(opener.requests) == 2
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
    assert opener.timeouts == [30, 30]


def test_authenticate_builds_a_cookie_aware_default_opener(
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
                    AWSELB='awselb-value',
                ),
            ],
        )

    monkeypatch.setattr(
        helper.urllib.request,
        'build_opener',
        fake_build_opener,
    )

    result = helper.authenticate(
        {
            'splunk_cloud': 'https://splunk.example.com',
            'username': 'test-user',
            'password': 'test-password',
        }
    )

    assert isinstance(captured['cookie_jar'], http.cookiejar.CookieJar)
    assert result['splunkweb_csrf_token_8443'] == 'csrf-value'


def test_authenticate_preserves_initial_cookies_when_login_clears_them() -> None:
    helper = load_helper()
    cookie_jar = []

    def replace_initial_cookies() -> None:
        cookie_jar.clear()
        add_cookies(
            cookie_jar,
            splunkweb_csrf_token_8443='csrf-value',
            splunkd_8443='splunkd-value',
            AWSELB='awselb-value',
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
        {
            'splunk_cloud': 'https://splunk.example.com',
            'username': 'test-user',
            'password': 'test-password',
        },
        opener=opener,
        cookie_jar=cookie_jar,
    )

    assert result == {
        'splunkweb_uid': 'initial-uid',
        'cval': 'initial-cval',
        'splunkweb_csrf_token_8443': 'csrf-value',
        'splunkd_8443': 'splunkd-value',
        'awselb': 'awselb-value',
    }


def test_fetch_config_preserves_the_top_level_aws_contract() -> None:
    helper = load_helper()
    opener = RecordingOpener(
        [
            json.dumps(
                {
                    'aws': {
                        'iamExternalId': 'external-id-123',
                        'instanceIamRole': (
                            'arn:aws:iam::999999999999:role/splunk-dm'
                        ),
                    },
                    'ignored': 'value',
                }
            ).encode('utf-8')
        ]
    )

    result = helper.fetch_config(
        {
            'splunk_cloud': 'https://splunk.example.com',
            'splunkweb_csrf_token_8443': 'csrf-value',
            'splunkd_8443': 'splunkd-value',
            'awselb': 'awselb-value',
        },
        opener=opener,
    )

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


def test_authenticate_rejects_an_incomplete_cookie_response() -> None:
    helper = load_helper()
    cookie_jar = []
    opener = RecordingOpener(
        [b'initial login'],
        callbacks=[lambda: add_cookies(cookie_jar, cval='cval-value')],
    )

    with pytest.raises(
        helper.ExternalDataError,
        match='splunkweb_uid',
    ):
        helper.authenticate(
            {
                'splunk_cloud': 'https://splunk.example.com',
                'username': 'test-user',
                'password': 'test-password',
            },
            opener=opener,
            cookie_jar=cookie_jar,
        )


@pytest.mark.parametrize(
    'body',
    [b'not-json', b'{"not_aws": {}}', b'{"aws": {"retries": 3}}'],
)
def test_fetch_config_rejects_invalid_external_results(body: bytes) -> None:
    helper = load_helper()
    opener = RecordingOpener([body])

    with pytest.raises(helper.ExternalDataError):
        helper.fetch_config(
            {
                'splunk_cloud': 'https://splunk.example.com',
                'splunkweb_csrf_token_8443': 'csrf-value',
                'splunkd_8443': 'splunkd-value',
                'awselb': 'awselb-value',
            },
            opener=opener,
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
        input_stream=io.StringIO(
            json.dumps(
                {
                    'splunk_cloud': 'https://splunk.example.com',
                    'splunkweb_csrf_token_8443': 'csrf',
                    'splunkd_8443': 'splunkd',
                    'awselb': 'awselb',
                }
            )
        ),
        output_stream=output,
        error_stream=io.StringIO(),
    )

    assert return_code == 0
    assert output.getvalue() == (
        '{"iamExternalId":"id","instanceIamRole":"role"}\n'
    )


def test_terraform_uses_python_and_stdin_queries_for_both_sources() -> None:
    terraform_source = TERRAFORM_PATH.read_text(encoding='utf-8')

    assert terraform_source.count('scripts/splunk_data_manager.py') == 2
    assert terraform_source.count('"python3"') == 2
    assert '"authenticate"' in terraform_source
    assert '"config"' in terraform_source
    assert 'username     = local.splunk_cloud_username' in terraform_source
    assert 'password     = local.splunk_cloud_password' in terraform_source
    assert '"bash", "-c"' not in terraform_source
    assert '/tmp/cookies' not in terraform_source
