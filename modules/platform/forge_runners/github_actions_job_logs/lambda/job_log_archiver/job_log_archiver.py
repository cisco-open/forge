import base64
import json
import logging
import os
import time
from typing import Any, Dict, Tuple
from urllib.parse import quote

import boto3
import jwt
import requests
from requests.exceptions import RequestException

LOG = logging.getLogger()
level_str = os.environ.get('LOG_LEVEL', 'INFO').upper()
LOG.setLevel(getattr(logging, level_str, logging.INFO))

SSM = boto3.client('ssm')
S3 = boto3.client('s3')

MAX_S3_TAGS = 10
GITHUB_RETRY_ATTEMPTS = 3
GITHUB_RETRY_DELAY = 2


def _get_secret_value(parameter_name: str) -> str:
    resp = SSM.get_parameter(Name=parameter_name, WithDecryption=True)
    return resp['Parameter']['Value']


def _generate_jwt(app_id: str, private_key_pem: str) -> str:
    now = int(time.time())
    payload = {'iat': now - 60, 'exp': now + 540, 'iss': app_id}
    token = jwt.encode(payload, private_key_pem, algorithm='RS256')
    if isinstance(token, bytes):
        token = token.decode()
    return token


def _retry_request(func, attempts=GITHUB_RETRY_ATTEMPTS, delay=GITHUB_RETRY_DELAY, **kwargs):
    for attempt in range(attempts):
        try:
            return func(**kwargs)
        except RequestException as e:
            if attempt < attempts - 1:
                LOG.warning('Retrying GitHub request due to error: %s', e)
                time.sleep(delay * (2 ** attempt))
            else:
                raise
    return None


def _get_installation_token(installation_id: str, jwt_token: str, api: str) -> str:
    url = f"{api}/app/installations/{installation_id}/access_tokens"
    headers = {'Authorization': f"Bearer {jwt_token}",
               'Accept': 'application/vnd.github+json'}
    r = _retry_request(requests.post, url=url, headers=headers, timeout=10)
    r.raise_for_status()
    return r.json()['token']


def _download_job_logs(owner: str, repo: str, job_id: int, token: str, api: str) -> bytes:
    url = f"{api}/repos/{owner}/{repo}/actions/jobs/{job_id}/logs"
    headers = {'Authorization': f"token {token}",
               'Accept': 'application/vnd.github+json'}

    r = _retry_request(requests.get, url=url, headers=headers, timeout=60)
    if r.status_code == 404:
        raise RuntimeError(f"Job logs not found (job_id={job_id})")
    r.raise_for_status()
    return r.content


def _serialize_tags(tags: Dict[str, str]) -> str:
    # Only keep first MAX_S3_TAGS keys
    safe_tags = {k: v for i, (k, v) in enumerate(
        tags.items()) if i < MAX_S3_TAGS and v is not None}
    return '&'.join(f"{quote(k, safe='')}={quote(v, safe='')}" for k, v in safe_tags.items())


def _put_log_object(bucket: str, key: str, body: bytes, kms_key_arn: str, tags: Dict[str, str]) -> None:
    extra: Dict[str, Any] = {
        'ContentType': 'text/plain',
        'ServerSideEncryption': 'aws:kms',
        'SSEKMSKeyId': kms_key_arn,
        'Tagging': _serialize_tags(tags),
    }
    S3.put_object(Bucket=bucket, Key=key, Body=body, **extra)


def _put_json_object(bucket: str, key: str, payload: Dict[str, Any], kms_key_arn: str, tags: Dict[str, str]) -> None:
    body = json.dumps(payload, separators=(',', ':'),
                      ensure_ascii=False).encode()
    extra: Dict[str, Any] = {
        'ContentType': 'application/json',
        'ServerSideEncryption': 'aws:kms',
        'SSEKMSKeyId': kms_key_arn,
        'Tagging': _serialize_tags(tags),
    }
    S3.put_object(Bucket=bucket, Key=key, Body=body, **extra)


def _parse_event(event: Dict[str, Any]) -> Tuple[Dict[str, Any], Dict[str, Any]]:
    if isinstance(event.get('Records'), list) and event['Records']:
        raw_body = event['Records'][0].get('body', '{}')
        try:
            gh_event = json.loads(raw_body)
        except json.JSONDecodeError:
            raise ValueError('invalid_json')
    else:
        gh_event = event
    detail = gh_event.get('detail', {})
    workflow_job = detail.get('workflow_job') or {}
    return gh_event, workflow_job


def _get_env() -> Dict[str, str]:
    keys = [
        'SECRET_NAME_APP_ID', 'SECRET_NAME_PRIVATE_KEY', 'SECRET_NAME_INSTALLATION_ID',
        'BUCKET_NAME', 'KMS_KEY_ARN', 'GITHUB_API'
    ]
    env = {k: os.getenv(k) for k in keys}
    missing = [k for k, v in env.items() if not v]
    if missing:
        raise RuntimeError(f'missing_env:{";".join(missing)}')
    return env


def _github_auth(secret_app_id: str, secret_private_key: str, secret_installation_id: str, api_base: str) -> str:
    app_id = _get_secret_value(secret_app_id).strip()
    installation_id = _get_secret_value(secret_installation_id).strip()
    private_key_b64 = _get_secret_value(secret_private_key).strip()
    private_key_pem = base64.b64decode(
        private_key_b64).decode().replace('\\n', '\n')
    jwt_token = _generate_jwt(app_id, private_key_pem)
    return _get_installation_token(installation_id, jwt_token, api_base)


def _keys(repo_full_name: str, run_id: Any, run_attempt: Any, job_id: Any) -> Tuple[str, str, str]:
    run_attempt = run_attempt or 1
    base_path = f"{repo_full_name}/{run_id}/{run_attempt}/{job_id}"
    return base_path, f"{base_path}.log", f"{base_path}.json"


def _tags(wf: Dict[str, Any]) -> Dict[str, str]:
    return {
        'runner_name': str(wf.get('runner_name') or ''),
        'conclusion': str(wf.get('conclusion') or ''),
        'status': str(wf.get('status') or ''),
        'html_url': str(wf.get('html_url') or ''),
        'created_at': str(wf.get('created_at') or ''),
        'started_at': str(wf.get('started_at') or ''),
        'completed_at': str(wf.get('completed_at') or ''),
    }


def lambda_handler(event: Dict[str, Any], _context: Any) -> Dict[str, Any]:  # pragma: no cover
    try:
        LOG.debug('Event: %s', json.dumps(event))
        try:
            gh_event, workflow_job = _parse_event(event)
        except Exception as e:
            raise ValueError('invalid_json Error: %s', str(e))

        detail = gh_event.get('detail', {})
        if detail.get('action') != 'completed' or not workflow_job:
            LOG.info(
                'Event action is not completed or workflow_job is missing, ignoring.')
            return {'status': 'ignored'}

        conclusion = workflow_job.get('conclusion')

        if conclusion in ('skipped', 'cancelled'):
            LOG.info(
                'Job conclusion is %s, skipping log archival. Workflow job: %s',
                conclusion,
                workflow_job,
            )
            return {'status': 'ignored'}

        repo_full_name = (detail.get('repository') or {}).get('full_name')
        if not repo_full_name:
            LOG.info(
                'Missing repository full_name in event detail. Detail event: %s', detail)
            raise ValueError('missing_repository')

        try:
            env = _get_env()
        except Exception as e:
            raise ValueError('missing_env. Error: %s', str(e))

        owner, repo = repo_full_name.split('/', 1)
        job_id = workflow_job.get('id')
        run_id = workflow_job.get('run_id')
        runner_name = workflow_job.get('runner_name')
        run_attempt = workflow_job.get('run_attempt')
        workflow_name = workflow_job.get('workflow_name')

        if not all([runner_name, run_id, job_id]):
            LOG.info('Missing required IDs: runner_name=%s run_id=%s job_id=%s. Workflow job: %s',
                     runner_name, run_id, job_id, workflow_job)
            raise ValueError('missing_ids')

        try:
            install_token = _github_auth(
                env['SECRET_NAME_APP_ID'], env['SECRET_NAME_PRIVATE_KEY'], env['SECRET_NAME_INSTALLATION_ID'], env['GITHUB_API']
            )
            _, log_key, event_key = _keys(
                repo_full_name, run_id, run_attempt, job_id)
            obj_tags = _tags(workflow_job)
            body = _download_job_logs(owner, repo, int(
                job_id), install_token, env['GITHUB_API'])
            _put_log_object(env['BUCKET_NAME'], log_key, body,
                            env['KMS_KEY_ARN'], obj_tags)
            size = len(body)
            _put_json_object(env['BUCKET_NAME'], event_key,
                             detail, env['KMS_KEY_ARN'], obj_tags)

            return {
                'status': 'ok',
                'job_id': job_id,
                'run_id': run_id,
                'run_attempt': run_attempt,
                'workflow_name': workflow_name,
                'repository': repo_full_name,
                'log_key': log_key,
                'event_key': event_key,
                'size': size
            }
        except Exception as e:
            raise ValueError(
                'archiver_error: job_id=%s run_id=%s. Error: %s', job_id, run_id, str(e))
    except Exception as e:
        LOG.exception(
            'Unhandled exception in job_log_archiver lambda. Error: %s', str(e))
