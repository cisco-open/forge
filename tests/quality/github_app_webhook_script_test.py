"""Unit tests for the GitHub App webhook update script."""

from __future__ import annotations

import base64
import importlib.util
import io
import json
import subprocess
from pathlib import Path
from types import SimpleNamespace
from urllib.error import HTTPError

import pytest

SCRIPT_PATH = Path(__file__).resolve().parents[2].joinpath(
    'modules/platform/forge_runners/scripts/generate_and_patch_github_app.py'
)
SCRIPT_SPEC = importlib.util.spec_from_file_location(
    'generate_and_patch_github_app', SCRIPT_PATH
)
assert SCRIPT_SPEC is not None and SCRIPT_SPEC.loader is not None
webhook_script = importlib.util.module_from_spec(SCRIPT_SPEC)
SCRIPT_SPEC.loader.exec_module(webhook_script)


def _decode_jwt_segment(segment: str) -> dict:
    padding = '=' * (-len(segment) % 4)
    return json.loads(base64.urlsafe_b64decode(segment + padding))


def test_generate_jwt_signs_expected_header_and_payload(monkeypatch):
    signing_call = {}

    def fake_run(command, **kwargs):
        key_path = Path(command[-1])
        signing_call['command'] = command
        signing_call['key'] = key_path.read_text(encoding='utf-8')
        signing_call['input'] = kwargs['input']
        signing_call['key_path'] = key_path
        assert kwargs['check'] is True
        return SimpleNamespace(stdout=b'signed-value')

    monkeypatch.setattr(webhook_script.subprocess, 'run', fake_run)

    jwt = webhook_script.generate_jwt(
        'client-123', 'test-private-key', now=1_700_000_000
    )

    header, payload, signature = jwt.split('.')
    assert _decode_jwt_segment(header) == {'typ': 'JWT', 'alg': 'RS256'}
    assert _decode_jwt_segment(payload) == {
        'iat': 1_699_999_940,
        'exp': 1_700_000_600,
        'iss': 'client-123',
    }
    assert base64.urlsafe_b64decode(signature + '==') == b'signed-value'
    assert signing_call['command'][:4] == [
        'openssl',
        'dgst',
        '-sha256',
        '-sign',
    ]
    assert signing_call['key'] == 'test-private-key'
    assert signing_call['input'] == f'{header}.{payload}'.encode('ascii')
    assert not signing_call['key_path'].exists()


def test_generate_jwt_propagates_openssl_failure(monkeypatch):
    def fail_run(*_args, **_kwargs):
        raise subprocess.CalledProcessError(
            1, 'openssl', stderr=b'Could not read private key'
        )

    monkeypatch.setattr(webhook_script.subprocess, 'run', fail_run)

    with pytest.raises(
        webhook_script.WebhookUpdateError,
        match='Could not read private key',
    ):
        webhook_script.generate_jwt('client-123', 'invalid-key')


class _Response:
    status = 200
    headers = {'Content-Type': 'application/json'}

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return None

    def read(self):
        return b'{"url":"https://webhook.example"}'


def test_patch_github_webhook_sends_request_and_saves_response(tmp_path):
    requests = []

    def opener(request):
        requests.append(request)
        return _Response()

    webhook_script.patch_github_webhook(
        jwt='jwt-value',
        github_api='https://api.github.example',
        webhook_url='https://webhook.example',
        secret='webhook-secret',
        prefix='test-forge',
        debug=False,
        response_dir=tmp_path,
        opener=opener,
    )

    assert len(requests) == 1
    request = requests[0]
    assert request.full_url == 'https://api.github.example/app/hook/config'
    assert request.get_method() == 'PATCH'
    assert request.get_header('Authorization') == 'Bearer jwt-value'
    assert json.loads(request.data) == {
        'url': 'https://webhook.example',
        'content_type': 'json',
        'insecure_ssl': '0',
        'secret': 'webhook-secret',
    }
    assert (tmp_path / 'test-forge-github_api_response.log').read_bytes() == (
        b'{"url":"https://webhook.example"}'
    )


def test_patch_github_webhook_raises_for_non_success_response(tmp_path):
    def opener(request):
        raise HTTPError(
            request.full_url,
            401,
            'Unauthorized',
            {'Content-Type': 'application/json'},
            io.BytesIO(b'{"message":"Bad credentials"}'),
        )

    with pytest.raises(
        webhook_script.WebhookUpdateError,
        match='HTTP status 401',
    ):
        webhook_script.patch_github_webhook(
            jwt='bad-jwt',
            github_api='https://api.github.example',
            webhook_url='https://webhook.example',
            secret='webhook-secret',
            prefix='test-forge',
            debug=False,
            response_dir=tmp_path,
            opener=opener,
        )

    assert (tmp_path / 'test-forge-github_api_response.log').read_bytes() == (
        b'{"message":"Bad credentials"}'
    )


def test_main_rejects_missing_environment_variables():
    with pytest.raises(
        webhook_script.WebhookUpdateError,
        match='CLIENT_ID',
    ):
        webhook_script.main({})
