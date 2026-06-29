"""DLQ redrive correctness (register P1-11).

Target: .../forge_runners/redrive_deadletter/lambda/redrive_deadletter.py

The lambda parses an SQS_MAP env var and starts a native SQS message-move task
per mapping. Tested: SQS_MAP parsing (malformed input rejected, not silently
mis-parsed), empty-map no-op, and that a move task is started against the DLQ.
"""

from __future__ import annotations

import json

import pytest
from conftest import requires_aws
from support import load_handler_module

pytestmark = requires_aws


def test_parse_sqs_map_valid(monkeypatch):
    mod = load_handler_module('redrive_deadletter')
    raw = json.dumps(
        {'runner-a': {'main': 'arn:main:a', 'dlq': 'arn:dlq:a'}}
    )
    out = mod.parse_sqs_map(raw)
    assert out == [
        {'key': 'runner-a', 'main': 'arn:main:a', 'dlq': 'arn:dlq:a'}]


def test_parse_sqs_map_empty_is_empty_list(monkeypatch):
    mod = load_handler_module('redrive_deadletter')
    assert mod.parse_sqs_map('') == []
    assert mod.parse_sqs_map('   ') == []


def test_parse_sqs_map_missing_keys_raises(monkeypatch):
    mod = load_handler_module('redrive_deadletter')
    with pytest.raises(Exception):
        mod.parse_sqs_map(json.dumps({'runner-a': {'main': 'arn:main:a'}}))


def test_parse_sqs_map_bad_json_raises(monkeypatch):
    mod = load_handler_module('redrive_deadletter')
    with pytest.raises(Exception):
        mod.parse_sqs_map('{not json')


def test_empty_map_is_noop(monkeypatch):
    mod = load_handler_module('redrive_deadletter')
    monkeypatch.setenv('SQS_MAP', '')
    result = mod.lambda_handler({}, None)
    assert result['status'] == 'noop'


def test_redrive_starts_move_task_per_mapping(monkeypatch, sqs):
    mod = load_handler_module('redrive_deadletter')
    # moto 5.x does not implement start_message_move_task; stub it so we can
    # assert the handler calls it correctly (the live path is covered by the
    # MiniStack/LocalStack smoke suite).
    calls = []
    monkeypatch.setattr(
        mod.sqs, 'start_message_move_task',
        lambda **kw: calls.append(kw) or {'TaskHandle': 'task-123'},
    )
    sqs_map = {
        'jobs': {'main': sqs['main_arn'], 'dlq': sqs['dlq_arn']},
    }
    monkeypatch.setenv('SQS_MAP', json.dumps(sqs_map))
    result = mod.lambda_handler({}, None)
    assert result['status'] == 'ok'
    assert len(result['results']) == 1
    entry = result['results'][0]
    assert entry['key'] == 'jobs'
    assert entry['status'] == 'started'
    assert entry['dlq'] == sqs['dlq_arn']
    # Handler must move FROM the DLQ (SourceArn = the dead-letter queue).
    assert calls and calls[0].get('SourceArn') == sqs['dlq_arn']
