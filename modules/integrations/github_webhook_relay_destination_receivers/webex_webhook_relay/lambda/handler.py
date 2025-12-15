import json
import logging
import os
import urllib.error
import urllib.request
from typing import Any, Dict

import boto3

LOG = logging.getLogger()
level_str = os.environ.get('LOG_LEVEL', 'INFO').upper()
LOG.setLevel(getattr(logging, level_str, logging.INFO))

DEFAULT_FAILURES = {'cancelled', 'failure',
                    'timed_out', 'timeout', 'startup_failure'}


def build_slack_card(run: Dict[str, Any], payload: Dict[str, Any]) -> Dict[str, Any]:
    repo = (payload.get('repository') or {}).get('full_name') or (
        run.get('head_repository') or {}).get('full_name') or 'unknown repo'
    workflow = run.get('name') or 'unknown workflow'
    conclusion = (run.get('conclusion') or 'unknown').lower()
    url = run.get('html_url')
    attempt = run.get('run_attempt') or 1
    triggering_actor = (run.get('triggering_actor') or {}).get('login') if isinstance(
        run.get('triggering_actor'), dict) else run.get('triggering_actor') or 'unknown'
    event = run.get('event') or 'unknown'
    actor = (run.get('actor') or {}).get('login') if isinstance(
        run.get('actor'), dict) else run.get('actor') or 'unknown'
    sha = (run.get('head_sha') or '')[:12]

    color = '#ff0000' if conclusion != 'success' else '#36a64f'

    fields = [
        {'type': 'mrkdwn', 'text': f"*Workflow:* {workflow}"},
        {'type': 'mrkdwn', 'text': f"*Conclusion:* {conclusion}"},
        {'type': 'mrkdwn', 'text': f"*Run Attempt:* {attempt}"},
        {'type': 'mrkdwn', 'text': f"*Event:* {event}"},
        {'type': 'mrkdwn', 'text': f"*Actor:* {actor}"},
        {'type': 'mrkdwn', 'text': f"*SHA:* {sha}"},
    ]

    if attempt > 1:
        fields.append(
            {'type': 'mrkdwn', 'text': f"*Re-run triggered by:* {triggering_actor}"})

    card = {
        'blocks': [
            {'type': 'header', 'text': {'type': 'plain_text',
                                        'text': f"GitHub Actions: {repo}", 'emoji': True}},
            {'type': 'section', 'fields': fields},
        ]
    }

    if url:
        card['blocks'].append({
            'type': 'section',
            'text': {'type': 'mrkdwn', 'text': f"<{url}|View Workflow Run>"}
        })

    card['attachments'] = [{'color': color}]

    return card


def slack_card_to_adaptive_card(card: Dict[str, Any]) -> Dict[str, Any]:
    conclusion = ''
    for block in card.get('blocks', []):
        if block.get('type') == 'section' and 'fields' in block:
            for f in block['fields']:
                if 'Conclusion' in f['text']:
                    conclusion = f['text'].split(':')[1].strip().lower()
                    break

    status_icon = '❌' if conclusion != 'success' else '✅'

    header_text = ''
    for block in card.get('blocks', []):
        if block.get('type') == 'header':
            header_text = block['text']['text']
            break

    body_fields = []
    for block in card.get('blocks', []):
        if block.get('type') == 'section' and 'fields' in block:
            for f in block['fields']:
                body_fields.append({
                    'type': 'TextBlock',
                    'text': f['text'].replace('*', '**'),
                    'wrap': True,
                    'spacing': 'Small',
                    'isSubtle': True
                })

    for block in card.get('blocks', []):
        if block.get('type') == 'section' and 'text' in block:
            url_text = block['text']['text']
            if '|' in url_text:
                url, text = url_text[1:-1].split('|')
            else:
                url, text = url_text, url_text
            body_fields.append({
                'type': 'TextBlock',
                'text': f"[{text}]({url})",
                'wrap': True,
                'spacing': 'Small',
                'isSubtle': True
            })

    adaptive_card = {
        'attachments': [
            {
                'contentType': 'application/vnd.microsoft.card.adaptive',
                'content': {
                    '$schema': 'http://adaptivecards.io/schemas/adaptive-card.json',
                    'type': 'AdaptiveCard',
                    'version': '1.2',
                    'body': [
                        {
                            'type': 'ColumnSet',
                            'columns': [
                                {'type': 'Column', 'width': 'auto', 'items': [
                                    {'type': 'TextBlock',
                                        'text': status_icon, 'size': 'Large'}
                                ]},
                                {'type': 'Column', 'width': 'stretch', 'items': [
                                    {'type': 'TextBlock', 'text': header_text,
                                        'weight': 'Bolder', 'size': 'Medium', 'wrap': True}
                                ]}
                            ]
                        },
                        *body_fields
                    ]
                }
            }
        ]
    }

    return adaptive_card


def load_webex_secret() -> tuple[str, str]:
    secret_name = os.getenv('WEBEX_BOT_TOKEN_SECRET_NAME')
    if not secret_name:
        raise RuntimeError('WEBEX_BOT_TOKEN_SECRET_NAME not set')

    client = boto3.client('secretsmanager')
    try:
        response = client.get_secret_value(SecretId=secret_name)
        secret_string = response.get('SecretString')
        if not secret_string:
            raise RuntimeError(f"No SecretString found for {secret_name}")
        secret = json.loads(secret_string)
    except Exception as e:
        raise RuntimeError(
            f"Failed to retrieve or parse secret {secret_name}: {e}") from e

    token = secret.get('token')
    room = secret.get('room_id')
    if not token or not room:
        raise RuntimeError(
            "Both 'token' and 'room_id' must be provided in secret")
    if not token.lower().startswith('bearer '):
        token = f"Bearer {token}"

    LOG.info('Successfully loaded Webex secret.')
    return token, room


def send_webex_card(card: Dict[str, Any]) -> None:
    token, room = load_webex_secret()
    payload = {
        'roomId': room,
        'text': 'GitHub Actions workflow alert',  # required by Webex
        'attachments': card.get('attachments', [])
    }
    LOG.info('Prepared payload for Webex message with %d attachments',
             len(payload.get('attachments', [])))

    req = urllib.request.Request(
        'https://webexapis.com/v1/messages',
        data=json.dumps(payload).encode('utf-8'),
        headers={'Authorization': token, 'Content-Type': 'application/json'},
        method='POST'
    )

    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            if not (200 <= resp.status < 300):
                body = resp.read().decode()
                raise RuntimeError(f"Webex send failed: {resp.status} {body}")
            LOG.info('Webex Adaptive Card sent successfully')
    except urllib.error.HTTPError as e:
        error_body = e.read().decode()
        raise RuntimeError(
            f"Webex send error: HTTP {e.code} {error_body}") from e
    except urllib.error.URLError as e:
        raise RuntimeError(f"Webex send error: {e}") from e


def lambda_handler(event, _context):
    try:
        detail = event.get('detail', {})
        run = detail.get('workflow_run')
        if not isinstance(run, dict):
            LOG.info('lambda_skip reason=no_workflow_run')
            return {'statusCode': 200, 'body': 'No workflow_run'}

        branch = run.get('head_branch')
        conclusion = (run.get('conclusion') or '').lower()
        repo = (detail.get('repository') or {}).get('full_name') or (
            run.get('head_repository') or {}).get('full_name') or 'unknown repo'
        job_url = run.get('html_url')
        LOG.info('run_info repo=%s branch=%s conclusion=%s job_url=%s',
                 repo, branch, conclusion, job_url)

        if branch != 'main':
            LOG.info('lambda_skip reason=branch_not_main repo=%s branch=%s conclusion=%s job_url=%s',
                     repo, branch, conclusion, job_url)
            return {'statusCode': 200, 'body': f"Skipped (branch={branch})"}

        if conclusion not in DEFAULT_FAILURES:
            LOG.info('lambda_skip reason=non_failure repo=%s branch=%s conclusion=%s job_url=%s',
                     repo, branch, conclusion, job_url)
            return {'statusCode': 200, 'body': f"Skipped ({conclusion})"}

        slack_card = build_slack_card(run, detail)
        adaptive_card = slack_card_to_adaptive_card(slack_card)
        send_webex_card(adaptive_card)

        return {'statusCode': 200, 'body': 'Alert sent'}

    except Exception as e:
        LOG.exception(
            'Unhandled exception in webex_webhook_relay lambda. Error: %s',
            str(e),
        )
        raise
