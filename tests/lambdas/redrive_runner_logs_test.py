from __future__ import annotations

import pytest
from conftest import requires_aws
from support import load_handler_module

pytestmark = requires_aws


def test_redrive_healthcheck_does_not_call_sqs(monkeypatch, aws):
    mod = load_handler_module('redrive_runner_logs')

    def unexpected_move_task(**_kwargs):
        raise AssertionError('healthcheck must not call SQS')

    monkeypatch.setattr(
        mod.sqs,
        'start_message_move_task',
        unexpected_move_task,
    )

    assert mod.lambda_handler({'healthcheck': True}, None) == {
        'status': 'healthy',
    }


def test_redrive_starts_move_task_from_runner_logs_dlq(monkeypatch, aws):
    mod = load_handler_module('redrive_runner_logs')
    dlq_arn = 'arn:aws:sqs:us-west-2:123456789012:runner-logs-dlq'
    calls = []

    monkeypatch.setenv('DLQ_ARN', dlq_arn)
    monkeypatch.setattr(
        mod.sqs,
        'start_message_move_task',
        lambda **kwargs: calls.append(kwargs) or {'TaskHandle': 'task-123'},
    )

    result = mod.lambda_handler({}, None)

    assert calls == [{'SourceArn': dlq_arn}]
    assert result == {
        'status': 'started',
        'dlq': dlq_arn,
        'task_handle': 'task-123',
    }


def test_redrive_propagates_move_task_failure(monkeypatch, aws):
    mod = load_handler_module('redrive_runner_logs')
    monkeypatch.setenv(
        'DLQ_ARN',
        'arn:aws:sqs:us-west-2:123456789012:runner-logs-dlq',
    )

    def fail_move_task(**_kwargs):
        raise RuntimeError('redrive unavailable')

    monkeypatch.setattr(mod.sqs, 'start_message_move_task', fail_move_task)

    with pytest.raises(RuntimeError, match='redrive unavailable'):
        mod.lambda_handler({}, None)
