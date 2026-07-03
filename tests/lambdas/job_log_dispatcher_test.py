"""Job-log dispatcher: EventBridge workflow_job -> SQS routing."""

from __future__ import annotations

import json

import pytest
from conftest import requires_aws
from support import load_handler_module

pytestmark = requires_aws


def _load_dispatcher(monkeypatch, queue_url):
    monkeypatch.setenv('QUEUE_URL', queue_url)
    monkeypatch.setenv('REPO_TENANT_JSON', '{}')
    return load_handler_module('job_log_dispatcher')


def _workflow_job_event():
    return {
        'detail-type': 'workflow_job',
        'detail': {
            'action': 'completed',
            'repository': {'full_name': 'acme/app'},
            'workflow_job': {
                'id': 4242,
                'run_id': 99,
                'workflow_name': 'ci',
                'run_attempt': 2,
                'name': 'unit tests',
                'status': 'completed',
                'conclusion': 'success',
                'head_branch': 'main',
                'head_sha': 'abcdef1234567890',
                'labels': ['self-hosted', 'x64'],
            },
        },
    }


def test_non_workflow_job_event_is_ignored(monkeypatch, sqs):
    mod = _load_dispatcher(monkeypatch, sqs['main_url'])

    result = mod.lambda_handler({'detail-type': 'push'}, None)

    assert result['statusCode'] == 200
    assert json.loads(result['body']) == {'message': 'ignored event'}
    messages = sqs['client'].receive_message(
        QueueUrl=sqs['main_url'],
        MaxNumberOfMessages=1,
        WaitTimeSeconds=0,
    )
    assert 'Messages' not in messages


def test_workflow_job_event_is_enqueued_unchanged(monkeypatch, sqs):
    mod = _load_dispatcher(monkeypatch, sqs['main_url'])
    event = _workflow_job_event()

    result = mod.lambda_handler(event, None)

    assert result == {'enqueued': True}
    messages = sqs['client'].receive_message(
        QueueUrl=sqs['main_url'],
        MaxNumberOfMessages=1,
        WaitTimeSeconds=0,
    )['Messages']
    assert json.loads(messages[0]['Body']) == event


def test_sqs_send_failure_is_raised_for_lambda_retry(monkeypatch, sqs):
    mod = _load_dispatcher(monkeypatch, sqs['main_url'])

    def _raise_send_failure(**_kwargs):
        raise RuntimeError('sqs unavailable')

    monkeypatch.setattr(mod.sqs, 'send_message', _raise_send_failure)

    with pytest.raises(RuntimeError, match='sqs unavailable'):
        mod.lambda_handler(_workflow_job_event(), None)
