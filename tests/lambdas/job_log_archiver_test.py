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


def test_metadata_sidecar_contains_flat_fields(monkeypatch, s3_kms, ssm):
    alpha = s3_kms['buckets']['alpha']
    mod = _load_archiver(monkeypatch, s3_kms, ssm, bucket=alpha)
    monkeypatch.setattr(mod, '_download_job_logs',
                        lambda *a, **k: b'log-bytes')

    evt = _completed_event()
    body = json.loads(evt['Records'][0]['body'])
    body['detail']['repository'] = {
        'full_name': 'acme/app',
        'owner': {'login': 'acme', 'type': 'Organization'},
        'custom_properties': {'business-unit': 'Cloudsec'},
    }
    body['detail']['workflow_job']['steps'] = [
        {
            'name': 'Set up job',
            'status': 'completed',
            'conclusion': 'success',
            'number': 1,
        },
        {
            'name': 'Run tests',
            'status': 'completed',
            'conclusion': 'success',
            'number': 2,
        },
    ]
    evt['Records'][0]['body'] = json.dumps(body)

    result = mod.lambda_handler(evt, None)

    s3 = s3_kms['s3']
    metadata_key = result['metadata_key']
    assert metadata_key == 'acme/app/99/1/4242.fields'
    raw = s3.get_object(Bucket=alpha, Key=metadata_key)['Body'].read()
    payload = json.loads(raw)

    fields = payload['fields']
    assert payload['source_log_key'] == 'acme/app/99/1/4242.log'
    assert payload['source_event_key'] == 'acme/app/99/1/4242.json'
    assert fields['action'] == 'completed'
    assert fields['workflow_job_id'] == 4242
    assert fields['workflow_job_run_id'] == 99
    assert fields['workflow_job_steps_count'] == 2
    assert fields['workflow_job_steps_0_name'] == 'Set up job'
    assert fields['workflow_job_steps_1_name'] == 'Run tests'
    assert fields['repository_owner_login'] == 'acme'
    assert fields['repository_custom_properties_business_unit'] == 'Cloudsec'

    for key in ('acme/app/99/1/4242.log', 'acme/app/99/1/4242.json'):
        tags = {
            tag['Key']: tag['Value']
            for tag in s3.get_object_tagging(Bucket=alpha, Key=key)['TagSet']
        }
        assert tags['metadata_key'] == metadata_key


def test_metadata_flattening_sanitizes_names_and_truncates_values(
    monkeypatch, aws
):
    mod = load_handler_module('job_log_archiver')
    long_value = 'x' * (mod.MAX_METADATA_VALUE_LENGTH + 10)

    fields = mod._flatten_metadata_fields({
        'repository': {'full-name': 'acme/app'},
        'workflow_job': {
            'steps': [{'name': 'Set up job'}],
            'long value': long_value,
        },
        'ignored_none': None,
        'ignored_object': object(),
    })

    assert fields['repository_full_name'] == 'acme/app'
    assert fields['workflow_job_steps_count'] == 1
    assert fields['workflow_job_steps_0_name'] == 'Set up job'
    assert fields['workflow_job_long_value'] == (
        'x' * mod.MAX_METADATA_VALUE_LENGTH
    )
    assert 'ignored_none' not in fields
    assert 'ignored_object' not in fields


def test_metadata_flattening_stops_at_field_limit(monkeypatch, aws):
    mod = load_handler_module('job_log_archiver')
    monkeypatch.setattr(mod, 'MAX_METADATA_FIELDS', 2)

    fields = mod._flatten_metadata_fields({'a': 1, 'b': 2, 'c': 3})

    assert fields == {'a': 1, 'b': 2}


def test_s3_tag_serialization_encodes_drops_none_and_limits(monkeypatch, aws):
    mod = load_handler_module('job_log_archiver')

    encoded = mod._serialize_tags({
        'space key': 'a b',
        'slash': 'x/y',
        'equals': 'a=b',
        'empty': '',
        'none': None,
    })

    assert encoded.split('&') == [
        'space%20key=a%20b',
        'slash=x%2Fy',
        'equals=a%3Db',
        'empty=',
    ]

    many_tags = {f'k{i}': f'v{i}' for i in range(mod.MAX_S3_TAGS + 2)}

    limited = mod._serialize_tags(many_tags).split('&')

    assert len(limited) == mod.MAX_S3_TAGS
    assert limited[-1] == f'k{mod.MAX_S3_TAGS - 1}=v{mod.MAX_S3_TAGS - 1}'


def test_github_request_retry_retries_then_succeeds(monkeypatch, aws):
    mod = load_handler_module('job_log_archiver')
    sleeps = []
    calls = []
    monkeypatch.setattr(mod.time, 'sleep',
                        lambda seconds: sleeps.append(seconds))

    def _flaky(**kwargs):
        calls.append(kwargs)
        if len(calls) < 3:
            raise mod.RequestException('temporary github failure')
        return {'ok': True}

    result = mod._retry_request(
        _flaky,
        attempts=3,
        delay=2,
        url='https://api.github.test',
    )

    assert result == {'ok': True}
    assert calls == [
        {'url': 'https://api.github.test'},
        {'url': 'https://api.github.test'},
        {'url': 'https://api.github.test'},
    ]
    assert sleeps == [2, 4]


def test_github_request_retry_raises_after_final_attempt(monkeypatch, aws):
    mod = load_handler_module('job_log_archiver')
    sleeps = []
    calls = []
    monkeypatch.setattr(mod.time, 'sleep',
                        lambda seconds: sleeps.append(seconds))

    def _always_fails(**kwargs):
        calls.append(kwargs)
        raise mod.RequestException('github timeout')

    with pytest.raises(mod.RequestException, match='github timeout'):
        mod._retry_request(
            _always_fails,
            attempts=3,
            delay=1,
            url='https://api.github.test',
        )

    assert calls == [
        {'url': 'https://api.github.test'},
        {'url': 'https://api.github.test'},
        {'url': 'https://api.github.test'},
    ]
    assert sleeps == [1, 2]


def test_parse_event_rejects_malformed_sqs_body(monkeypatch, aws):
    mod = load_handler_module('job_log_archiver')

    with pytest.raises(ValueError, match='invalid_json'):
        mod._parse_event({'Records': [{'body': '{"detail":'}]})


def test_missing_runtime_env_fails_before_side_effects(monkeypatch, aws):
    mod = load_handler_module('job_log_archiver')
    for key in (
        'SECRET_NAME_APP_ID',
        'SECRET_NAME_PRIVATE_KEY',
        'SECRET_NAME_INSTALLATION_ID',
        'BUCKET_NAME',
        'KMS_KEY_ARN',
        'GITHUB_API',
    ):
        monkeypatch.delenv(key, raising=False)

    with pytest.raises(ValueError, match='missing_env'):
        mod.lambda_handler(_completed_event(), None)


def test_missing_repository_is_rejected_without_github_or_s3_side_effects(
    monkeypatch, s3_kms, ssm
):
    alpha = s3_kms['buckets']['alpha']
    mod = _load_archiver(monkeypatch, s3_kms, ssm, bucket=alpha)
    monkeypatch.setattr(
        mod,
        '_download_job_logs',
        lambda *_args, **_kwargs: (_ for _ in ()).throw(
            AssertionError('missing repository must not call GitHub')
        ),
    )
    evt = _completed_event()
    body = json.loads(evt['Records'][0]['body'])
    body['detail']['repository'] = {}
    evt['Records'][0]['body'] = json.dumps(body)

    with pytest.raises(ValueError, match='missing_repository'):
        mod.lambda_handler(evt, None)

    assert s3_kms['s3'].list_objects_v2(Bucket=alpha).get('Contents', []) == []


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


def test_archival_failure_propagates_for_sqs_retry(monkeypatch, s3_kms, ssm):
    alpha = s3_kms['buckets']['alpha']
    mod = _load_archiver(monkeypatch, s3_kms, ssm, bucket=alpha)

    def _boom(*a, **k):
        raise RuntimeError('github 500')

    monkeypatch.setattr(mod, '_download_job_logs', _boom)
    # A correct handler surfaces the failure to SQS (raises); today it swallows.
    with pytest.raises(Exception):
        mod.lambda_handler(_completed_event(), None)
