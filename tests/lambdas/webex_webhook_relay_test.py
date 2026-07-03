"""Webex webhook relay receiver tests."""

from __future__ import annotations

import json

import boto3
from conftest import AWS_REGION, requires_aws
from support import load_handler_module

pytestmark = requires_aws


def _workflow_run_event(*, branch='main', conclusion='failure', attempt=1):
    return {
        'detail': {
            'repository': {'full_name': 'acme/app'},
            'workflow_run': {
                'name': 'ci',
                'conclusion': conclusion,
                'head_branch': branch,
                'html_url': 'https://github.com/acme/app/actions/runs/100',
                'run_attempt': attempt,
                'event': 'push',
                'actor': {'login': 'octocat'},
                'triggering_actor': {'login': 'rerunner'},
                'head_sha': 'abcdef1234567890',
                'head_repository': {'full_name': 'acme/app'},
            },
        },
    }


def test_build_slack_card_includes_rerun_actor_for_retry(monkeypatch, aws):
    mod = load_handler_module('webex_webhook_relay')
    run = _workflow_run_event(attempt=2)['detail']['workflow_run']

    card = mod.build_slack_card(run, {'repository': {'full_name': 'acme/app'}})

    field_text = [
        field['text']
        for block in card['blocks']
        for field in block.get('fields', [])
    ]
    assert '*Workflow:* ci' in field_text
    assert '*Conclusion:* failure' in field_text
    assert '*Re-run triggered by:* rerunner' in field_text
    assert card['attachments'] == [{'color': '#ff0000'}]


def test_adaptive_card_preserves_link_and_header(monkeypatch, aws):
    mod = load_handler_module('webex_webhook_relay')
    run = _workflow_run_event()['detail']['workflow_run']
    slack_card = mod.build_slack_card(
        run,
        {'repository': {'full_name': 'acme/app'}},
    )

    adaptive = mod.slack_card_to_adaptive_card(slack_card)

    body = adaptive['attachments'][0]['content']['body']
    body_text = json.dumps(body)
    assert 'GitHub Actions: acme/app' in body_text
    assert '[View Workflow Run]' in body_text
    assert 'https://github.com/acme/app/actions/runs/100' in body_text


def test_lambda_handler_skips_missing_workflow_run(monkeypatch, aws):
    mod = load_handler_module('webex_webhook_relay')
    monkeypatch.setattr(
        mod,
        'send_webex_card',
        lambda _card: (_ for _ in ()).throw(
            AssertionError('no alert should be sent')
        ),
    )

    result = mod.lambda_handler({'detail': {}}, None)

    assert result == {'statusCode': 200, 'body': 'No workflow_run'}


def test_lambda_handler_skips_non_main_or_non_failure(monkeypatch, aws):
    mod = load_handler_module('webex_webhook_relay')
    monkeypatch.setattr(
        mod,
        'send_webex_card',
        lambda _card: (_ for _ in ()).throw(
            AssertionError('no alert should be sent')
        ),
    )

    assert mod.lambda_handler(
        _workflow_run_event(branch='feature', conclusion='failure'),
        None,
    )['body'] == 'Skipped (branch=feature)'
    assert mod.lambda_handler(
        _workflow_run_event(branch='main', conclusion='success'),
        None,
    )['body'] == 'Skipped (success)'


def test_lambda_handler_sends_main_branch_failure(monkeypatch, aws):
    mod = load_handler_module('webex_webhook_relay')
    sent = []
    monkeypatch.setattr(mod, 'send_webex_card', lambda card: sent.append(card))

    result = mod.lambda_handler(_workflow_run_event(), None)

    assert result == {'statusCode': 200, 'body': 'Alert sent'}
    assert len(sent) == 1
    assert sent[0]['attachments'][0]['contentType'] == (
        'application/vnd.microsoft.card.adaptive'
    )


def test_load_webex_secret_adds_bearer_prefix(monkeypatch, aws):
    mod = load_handler_module('webex_webhook_relay')
    secret_name = '/forge/webex'
    boto3.client('secretsmanager', region_name=AWS_REGION).create_secret(
        Name=secret_name,
        SecretString=json.dumps({'token': 'token-123', 'room_id': 'room-1'}),
    )
    monkeypatch.setenv('WEBEX_BOT_TOKEN_SECRET_NAME', secret_name)

    token, room = mod.load_webex_secret()

    assert token == 'Bearer token-123'
    assert room == 'room-1'
