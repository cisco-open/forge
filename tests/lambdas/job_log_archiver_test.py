"""Job-log archiver: tenant-bucket routing + failure handling.

Target: .../github_actions_job_logs/lambda/job_log_archiver/job_log_archiver.py

Two behaviours matter most (register P1-8, P0-5):
  * Routing: a completed workflow_job's logs are written ONLY to the configured
    tenant bucket, under the repo-scoped key, KMS-encrypted — never to another
    tenant's bucket.
  * Failure handling: if archival fails, the handler must propagate the error so
    the SQS event-source mapping retries and ultimately routes to the DLQ.
    Today the handler swallows the exception (returns None) so the message is
    deleted and logs are lost silently — encoded as xfail(P0-5).

GitHub network calls are monkeypatched out; only AWS (moto) is exercised.
"""

from __future__ import annotations

import base64
import json

import pytest
from conftest import requires_aws
from support import load_handler_module

pytestmark = requires_aws


def _completed_event(repo='acme/app', job_id=4242, run_id=99, attempt=1):
    detail = {
        'action': 'completed',
        'repository': {'full_name': repo},
        'workflow_job': {
            'id': job_id,
            'run_id': run_id,
            'run_attempt': attempt,
            'runner_name': 'forge-runner-1',
            'workflow_name': 'ci',
            'status': 'completed',
            'conclusion': 'success',
        },
    }
    # Archiver receives an SQS record whose body is the EventBridge event.
    return {'Records': [{'body': json.dumps({'detail': detail})}]}


def _load_archiver(monkeypatch, s3_kms, ssm, *, bucket):
    # SSM secrets the archiver reads.
    ssm['client'].put_parameter(
        Name='/forge/app_id', Value='123456', Type='SecureString'
    )
    ssm['client'].put_parameter(
        Name='/forge/installation_id', Value='654321', Type='SecureString'
    )
    ssm['client'].put_parameter(
        Name='/forge/private_key',
        Value=base64.b64encode(b'FAKE-PEM').decode(),
        Type='SecureString',
    )
    monkeypatch.setenv('BUCKET_NAME', bucket)
    monkeypatch.setenv('KMS_KEY_ARN', s3_kms['key_arn'])
    monkeypatch.setenv('SECRET_NAME_APP_ID', '/forge/app_id')
    monkeypatch.setenv('SECRET_NAME_INSTALLATION_ID', '/forge/installation_id')
    monkeypatch.setenv('SECRET_NAME_PRIVATE_KEY', '/forge/private_key')
    monkeypatch.setenv('GITHUB_API', 'https://api.github.test')
    mod = load_handler_module('job_log_archiver')
    # Avoid real GitHub network: stub auth + log download.
    monkeypatch.setattr(mod, '_github_auth', lambda *a, **k: 'ghs_faketoken')
    return mod


def test_logs_written_only_to_configured_tenant_bucket(
    monkeypatch, s3_kms, ssm
):
    alpha = s3_kms['buckets']['alpha']
    bravo = s3_kms['buckets']['bravo']
    mod = _load_archiver(monkeypatch, s3_kms, ssm, bucket=alpha)
    monkeypatch.setattr(mod, '_download_job_logs',
                        lambda *a, **k: b'log-bytes')

    mod.lambda_handler(_completed_event(repo='acme/app', job_id=4242), None)

    s3 = s3_kms['s3']
    alpha_keys = [
        o['Key']
        for o in s3.list_objects_v2(Bucket=alpha).get('Contents', [])
    ]
    bravo_keys = [
        o['Key']
        for o in s3.list_objects_v2(Bucket=bravo).get('Contents', [])
    ]
    # Written to the configured tenant, under the repo-scoped key, and NOT to
    # the other tenant's bucket.
    assert any(k.startswith('acme/app/99/1/4242')
               for k in alpha_keys), alpha_keys
    assert bravo_keys == [], f"cross-tenant write leaked: {bravo_keys}"


def test_log_object_is_kms_encrypted(monkeypatch, s3_kms, ssm):
    alpha = s3_kms['buckets']['alpha']
    mod = _load_archiver(monkeypatch, s3_kms, ssm, bucket=alpha)
    monkeypatch.setattr(mod, '_download_job_logs',
                        lambda *a, **k: b'log-bytes')
    mod.lambda_handler(_completed_event(), None)
    s3 = s3_kms['s3']
    key = next(
        o['Key'] for o in s3.list_objects_v2(Bucket=alpha)['Contents']
        if o['Key'].endswith('.log')
    )
    head = s3.head_object(Bucket=alpha, Key=key)
    assert head.get('ServerSideEncryption') == 'aws:kms'


def test_skipped_jobs_are_not_archived(monkeypatch, s3_kms, ssm):
    alpha = s3_kms['buckets']['alpha']
    mod = _load_archiver(monkeypatch, s3_kms, ssm, bucket=alpha)
    monkeypatch.setattr(mod, '_download_job_logs', lambda *a, **k: b'x')
    evt = _completed_event()
    body = json.loads(evt['Records'][0]['body'])
    body['detail']['workflow_job']['conclusion'] = 'skipped'
    evt['Records'][0]['body'] = json.dumps(body)
    result = mod.lambda_handler(evt, None)
    assert result == {'status': 'ignored'}
    assert s3_kms['s3'].list_objects_v2(Bucket=alpha).get('Contents', []) == []


@pytest.mark.xfail(
    reason="P0-5: archiver's outer except logs but does not re-raise, so SQS "
    'deletes the message and the DLQ never fires (silent log loss). Fix: '
    're-raise on unhandled error.',
    strict=False,
)
def test_archival_failure_propagates_for_sqs_retry(monkeypatch, s3_kms, ssm):
    alpha = s3_kms['buckets']['alpha']
    mod = _load_archiver(monkeypatch, s3_kms, ssm, bucket=alpha)

    def _boom(*a, **k):
        raise RuntimeError('github 500')

    monkeypatch.setattr(mod, '_download_job_logs', _boom)
    # A correct handler surfaces the failure to SQS (raises); today it swallows.
    with pytest.raises(Exception):
        mod.lambda_handler(_completed_event(), None)
