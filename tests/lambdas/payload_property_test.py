"""Deterministic payload/property tests for untrusted Lambda inputs.

These complement the Atheris fuzzers under fuzz/ with fast pytest properties
that run hermetically. They use Hypothesis only when the pinned lambda-tests
dependency group is installed; otherwise this file skips cleanly.
"""

from __future__ import annotations

import base64
import binascii
import importlib
import json
import re
import sys
from pathlib import Path

import pytest
from conftest import requires_aws
from hypothesis import HealthCheck, example, given, settings
from hypothesis import strategies as st
from support import load_handler_module

hypothesis = pytest.importorskip('hypothesis')

pytestmark = [pytest.mark.fuzz, requires_aws]

_FUZZ_SETTINGS = settings(
    max_examples=50,
    derandomize=True,
    deadline=None,
    suppress_health_check=[HealthCheck.function_scoped_fixture],
)

_JSON_SCALAR = st.one_of(
    st.none(),
    st.booleans(),
    st.integers(min_value=-10**6, max_value=10**6),
    st.floats(allow_nan=False, allow_infinity=False, width=32),
    st.text(max_size=128),
)
_JSON_VALUE = st.recursive(
    _JSON_SCALAR,
    lambda children: st.one_of(
        st.lists(children, max_size=8),
        st.dictionaries(st.text(max_size=32), children, max_size=8),
    ),
    max_leaves=32,
)


def _load_stuck_handler(monkeypatch):
    lambda_dir = Path(__file__).resolve().parents[2].joinpath(
        'modules',
        'integrations',
        'splunk_stuck_workflow_job_dispatcher',
        'lambda',
    )
    src = str(lambda_dir)
    if src not in sys.path:
        sys.path.insert(0, src)
    monkeypatch.setenv('WEBHOOK_TOKEN', 'token-123')
    monkeypatch.setenv('DEDUPE_TABLE', 'payload-fuzz')
    monkeypatch.setenv('DEDUPE_TTL_SECONDS', '1800')
    sys.modules.pop('handler', None)
    return importlib.import_module('handler')


def _load_redrive(monkeypatch):
    monkeypatch.setenv('SQS_MAP', '{}')
    return load_handler_module('redrive_deadletter')


@_FUZZ_SETTINGS
@example(body='{"results":[]}', content_type='application/json', encoded=False)
@example(body='payload=%7B%22results%22%3A%5B%5D%7D',
         content_type='application/x-www-form-urlencoded', encoded=False)
@given(
    body=st.text(max_size=4096),
    content_type=st.sampled_from([
        'application/json',
        'application/x-www-form-urlencoded',
        'text/plain',
        '',
    ]),
    encoded=st.booleans(),
)
def test_stuck_dispatcher_body_parser_fails_safe_for_mutated_events(
    monkeypatch, aws, body, content_type, encoded
):
    mod = _load_stuck_handler(monkeypatch)
    event_body = body
    if encoded:
        event_body = base64.b64encode(body.encode('utf-8')).decode('ascii')
    event = {
        'headers': {'content-type': content_type},
        'body': event_body,
        'isBase64Encoded': encoded,
        'pathParameters': {'token': 'token-123'},
        'requestContext': {'http': {'method': 'POST'}},
    }

    try:
        payload = mod.parse_body(event)
    except (binascii.Error, json.JSONDecodeError, UnicodeDecodeError, ValueError):
        return

    assert isinstance(payload, dict)
    results = mod.extract_results(payload)
    assert isinstance(results, list)
    assert all(isinstance(item, dict) for item in results)


@_FUZZ_SETTINGS
@example(value={'repository': {'full-name': 'acme/app'}})
@given(value=_JSON_VALUE)
def test_archiver_metadata_flattening_is_bounded_and_tag_safe(
    monkeypatch, aws, value
):
    mod = load_handler_module('job_log_archiver')

    fields = mod._flatten_metadata_fields(value)

    assert len(fields) <= mod.MAX_METADATA_FIELDS
    for key, field_value in fields.items():
        assert re.fullmatch(r'[a-z0-9_]+', key)
        assert not key.startswith('_')
        assert not key.endswith('_')
        assert isinstance(field_value, (str, bool, int, float))
        if isinstance(field_value, str):
            assert len(field_value) <= mod.MAX_METADATA_VALUE_LENGTH


@_FUZZ_SETTINGS
@example(raw='{"jobs":{"main":"arn:aws:sqs:::main","dlq":"arn:aws:sqs:::dlq"}}')
@given(raw=st.text(max_size=2048))
def test_redrive_sqs_map_parser_rejects_or_returns_string_queue_pairs(
    monkeypatch, aws, raw
):
    mod = _load_redrive(monkeypatch)

    try:
        parsed = mod.parse_sqs_map(raw)
    except Exception as exc:
        assert 'SQS_MAP' in str(exc) or 'Invalid' in str(exc)
        return

    assert isinstance(parsed, list)
    for cfg in parsed:
        assert set(cfg) == {'key', 'main', 'dlq'}
        assert isinstance(cfg['key'], str)
        assert isinstance(cfg['main'], str)
        assert isinstance(cfg['dlq'], str)


@_FUZZ_SETTINGS
@example(raw='["arn:aws:iam::123456789012:role/one", ""]')
@given(raw=st.text(max_size=2048))
def test_trust_env_list_parser_returns_trimmed_non_empty_strings(
    monkeypatch, aws, raw
):
    mod = load_handler_module('trust_common')
    monkeypatch.setenv('FUZZ_LIST', raw)

    values = mod.parse_env_list('FUZZ_LIST')

    assert all(isinstance(value, str) for value in values)
    assert all(value == value.strip() for value in values)
    assert all(value for value in values)
