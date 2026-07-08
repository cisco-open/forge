from __future__ import annotations

import importlib.util
from pathlib import Path
from types import ModuleType

import pytest
from support import (make_apigw_v2_event, sign_sha1_legacy, sign_sha256,
                     webhook_body)

pytestmark = pytest.mark.mutation

SOURCE = Path(__file__).resolve().parents[2].joinpath(
    'modules/platform/forge_runners/github_webhook_relay/source/lambda/'
    'validate_signature.py',
)


class FakeEventBridge:
    def put_events(self, Entries):
        return {'FailedEntryCount': 0, 'Entries': [{'EventId': 'event-1'}]}


def load_mutant(tmp_path: Path, source: str, monkeypatch: pytest.MonkeyPatch) -> ModuleType:
    mutant_path = tmp_path / 'validate_signature.py'
    mutant_path.write_text(source, encoding='utf-8')

    monkeypatch.setenv('EVENT_BUS', 'test-bus')
    monkeypatch.setenv('WEBHOOK_SECRET', 'forge-test-not-a-real-secret')
    monkeypatch.setenv('LOG_LEVEL', 'INFO')

    import boto3

    monkeypatch.setattr(boto3, 'client', lambda service,
                        *_, **__: FakeEventBridge())

    spec = importlib.util.spec_from_file_location(
        'validate_signature_mutant', mutant_path)
    assert spec is not None
    assert spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


MUTANTS = {
    'accepts_missing_or_wrong_signature': [
        (
            'if not hmac.compare_digest(signature, expected_signature):',
            'if False:',
        ),
    ],
    'uses_legacy_sha1_digest': [
        (
            'hashlib.sha256).hexdigest()',
            'hashlib.sha1).hexdigest()',
        ),
    ],
    'trusts_legacy_sha1_header': [
        (
            "headers.get('x-hub-signature-256', '')",
            "headers.get('x-hub-signature', '')",
        ),
        (
            'hashlib.sha256).hexdigest()',
            'hashlib.sha1).hexdigest()',
        ),
        (
            'expected_signature = f"sha256={digest}"',
            'expected_signature = f"sha1={digest}"',
        ),
    ],
}


def mutated_source(name: str) -> str:
    source = SOURCE.read_text(encoding='utf-8')
    for old, new in MUTANTS[name]:
        assert old in source
        source = source.replace(old, new, 1)
    return source


def accepts(module: ModuleType, event: dict) -> bool:
    try:
        response = module.lambda_handler(event, None)
    except Exception:
        return False
    return response.get('statusCode') == 200


@pytest.mark.parametrize('mutant_name', sorted(MUTANTS))
def test_webhook_signature_security_mutants_are_killed(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    mutant_name: str,
) -> None:
    module = load_mutant(tmp_path, mutated_source(mutant_name), monkeypatch)

    body = webhook_body()
    valid_sha256 = make_apigw_v2_event(
        body, sign_sha256(b'forge-test-not-a-real-secret', body))
    missing_signature = make_apigw_v2_event(body, signature_256=None)
    wrong_secret = make_apigw_v2_event(
        body, sign_sha256(b'wrong-secret', body))
    legacy_sha1 = make_apigw_v2_event(body, signature_256=None)
    legacy_sha1['headers']['X-Hub-Signature'] = sign_sha1_legacy(
        b'forge-test-not-a-real-secret',
        body,
    )

    if mutant_name == 'accepts_missing_or_wrong_signature':
        assert accepts(module, missing_signature) or accepts(
            module, wrong_secret)
    elif mutant_name == 'uses_legacy_sha1_digest':
        assert not accepts(module, valid_sha256)
    elif mutant_name == 'trusts_legacy_sha1_header':
        assert accepts(module, legacy_sha1)
    else:
        raise AssertionError(f'Unhandled mutant: {mutant_name}')
