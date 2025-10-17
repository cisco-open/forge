import base64
import json
import logging
import os
import time
from typing import Any, Dict

import boto3
import jwt
import requests

LOG = logging.getLogger()
LOG.setLevel(logging.INFO)

SECRETS = boto3.client('secretsmanager')
S3 = boto3.client('s3')


def _get_secret_value(secret_id: str) -> str:
    resp = SECRETS.get_secret_value(SecretId=secret_id)
    if 'SecretString' in resp:
        return resp['SecretString']
    return base64.b64decode(resp['SecretBinary']).decode()


def _generate_jwt(app_id: str, private_key_pem: str) -> str:
    now = int(time.time())
    payload = {'iat': now - 60, 'exp': now + 540, 'iss': app_id}
    token = jwt.encode(payload, private_key_pem, algorithm='RS256')
    if isinstance(token, bytes):
        token = token.decode()
    return token


def _get_installation_token(installation_id: str, jwt_token: str, api: str) -> str:
    url = f"{api}/app/installations/{installation_id}/access_tokens"
    headers = {'Authorization': f"Bearer {jwt_token}",
               'Accept': 'application/vnd.github+json'}
    r = requests.post(url, headers=headers, timeout=10)
    r.raise_for_status()
    return r.json()['token']


# Previously we enumerated all jobs in a run; for workflow_job "completed" events
# only the single job's log needs archiving, so we removed the bulk listing logic.


def _download_job_logs(owner: str, repo: str, job_id: int, token: str, api: str) -> bytes:
    url = f"{api}/repos/{owner}/{repo}/actions/jobs/{job_id}/logs"
    headers = {'Authorization': f"token {token}",
               'Accept': 'application/vnd.github+json'}
    r = requests.get(url, headers=headers, timeout=60)
    if r.status_code == 404:
        # Logs may be unavailable briefly after completion
        raise RuntimeError(f"Job logs not found (job_id={job_id})")
    r.raise_for_status()
    return r.content


def _put_log_object(bucket: str, key: str, body: bytes, kms_key_arn: str) -> None:
    extra: Dict[str, Any] = {
        'ContentType': 'application/zip',
        'ServerSideEncryption': 'aws:kms',
        'SSEKMSKeyId': kms_key_arn,
    }
    S3.put_object(Bucket=bucket, Key=key, Body=body, **extra)


def _extract_repo_full_name(detail: Dict[str, Any], workflow_job: Dict[str, Any]) -> str | None:
    """Derive repository full_name from possible locations in the workflow_job event."""
    for candidate in (
        workflow_job.get('repository'),
        detail.get('repository'),
        workflow_job.get('head_repository'),
    ):
        if isinstance(candidate, dict):
            full = candidate.get('full_name')
            if full:
                return full
    return None


def lambda_handler(event: Dict[str, Any], _context: Any) -> Dict[str, Any]:  # pragma: no cover
    """Process a single workflow_job completed event delivered via SQS mapping.

    The SQS event source mapping is configured with batch_size=1 so we expect
    either {"Records": [{"body": "<event json>"}]} or a direct test invocation
    containing the event JSON itself.
    """
    LOG.debug('Event: %s', json.dumps(event))

    # When invoked via SQS event source mapping we receive {"Records": [{"body": "<json>"}]}
    if isinstance(event.get('Records'), list) and event['Records']:
        raw_body = event['Records'][0].get('body', '{}')
        try:
            gh_event = json.loads(raw_body)
        except json.JSONDecodeError:
            LOG.error('Invalid JSON in SQS body')
            return {'status': 'error', 'error': 'invalid_json'}
    else:
        gh_event = event

    detail = gh_event.get('detail', {})
    action = detail.get('action')
    workflow_job = detail.get('workflow_job') or {}
    if action != 'completed' or not workflow_job:
        LOG.info('Ignoring event (action=%s has_workflow_job=%s)',
                 action, bool(workflow_job))
        return {'status': 'ignored'}

    # Resolve repository full name before env validation dependent returns.
    repo_full_name = _extract_repo_full_name(detail, workflow_job)

    secret_app_id = os.getenv('SECRET_NAME_APP_ID')
    secret_private_key = os.getenv('SECRET_NAME_PRIVATE_KEY')
    secret_installation_id = os.getenv('SECRET_NAME_INSTALLATION_ID')
    bucket_name = os.getenv('BUCKET_NAME')
    kms_key_arn = os.getenv('KMS_KEY_ARN')
    api_base = os.getenv('GITHUB_API')

    if not all([secret_app_id, secret_private_key, secret_installation_id, bucket_name, api_base]):
        LOG.error('Missing required environment variables')
        return {'status': 'error', 'error': 'missing_env'}

    if not repo_full_name:
        LOG.warning('Missing repository full_name; skipping job_id=%s',
                    workflow_job.get('id'))
        return {'status': 'error', 'error': 'missing_repository'}

    owner, repo = repo_full_name.split('/', 1)
    job_id = workflow_job.get('id')
    run_id = workflow_job.get('run_id')
    run_attempt = workflow_job.get('run_attempt', 1)
    workflow_name = workflow_job.get(
        'workflow_name') or workflow_job.get('name') or 'unknown-workflow'

    if not all([job_id, run_id]):
        LOG.warning('Missing job_id or run_id in workflow_job; skipping')
        return {'status': 'error', 'error': 'missing_ids'}

    # Auth (single job so do it inline)
    app_id = _get_secret_value(secret_app_id).strip()
    installation_id = _get_secret_value(secret_installation_id).strip()
    private_key_b64 = _get_secret_value(secret_private_key).strip()
    private_key_pem = base64.b64decode(
        private_key_b64).decode().replace('\\n', '\n')
    jwt_token = _generate_jwt(app_id, private_key_pem)
    install_token = _get_installation_token(
        installation_id, jwt_token, api_base)

    # Use repository name instead of workflow name in object path (user request)
    key = f"{repo_full_name}/{run_id}/{run_attempt}/{job_id}.log"
    try:
        body = _download_job_logs(owner, repo, int(
            job_id), install_token, api_base)
        _put_log_object(bucket_name, key, body, kms_key_arn)
        size = len(body)
        LOG.info('Archived job log repo=%s run=%s attempt=%s job=%s size=%d bucket=%s key=%s',
                 repo_full_name, run_id, run_attempt, job_id, size, bucket_name, key)
        return {
            'status': 'ok',
            'job_id': job_id,
            'run_id': run_id,
            'run_attempt': run_attempt,
            'workflow_name': workflow_name,
            'repository': repo_full_name,
            'key': key,
            'size': size
        }
    except Exception as e:  # pragma: no cover
        LOG.warning('Failed to archive job_id=%s run_id=%s: %s',
                    job_id, run_id, e)
        return {'status': 'error', 'job_id': job_id, 'run_id': run_id, 'error': str(e)}
