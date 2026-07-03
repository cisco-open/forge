from __future__ import annotations

import json

from conftest import requires_aws
from support import load_handler_module

pytestmark = requires_aws


def _load_splunk(monkeypatch):
    monkeypatch.setenv('KINESIS_STREAM_NAME', 'splunk-runner-logs-test')
    return load_handler_module('splunk_s3_runner_logs')


def test_metadata_key_for_object(monkeypatch, aws):
    mod = _load_splunk(monkeypatch)

    assert mod.metadata_key_for_object(
        'acme/app/99/1/4242.log',
        {'metadata_key': 'metadata/custom.fields'},
    ) == 'metadata/custom.fields'
    assert mod.metadata_key_for_object('acme/app/99/1/4242.log') == (
        'acme/app/99/1/4242.fields'
    )
    assert mod.metadata_key_for_object('acme/app/99/1/4242.json') == (
        'acme/app/99/1/4242.fields'
    )


def test_load_metadata_fields_reads_sidecar(monkeypatch, s3_kms):
    mod = _load_splunk(monkeypatch)
    bucket = s3_kms['buckets']['alpha']
    s3 = s3_kms['s3']
    s3.put_object(
        Bucket=bucket,
        Key='metadata/custom.fields',
        Body=json.dumps({
            'fields': {
                'workflow_job_id': 4242,
                'repository_full_name': 'acme/app',
                'workflow_job_conclusion': 'success',
                'skip_nested': {'value': 'ignored'},
                'skip_list': ['ignored'],
                'skip_null': None,
            },
        }).encode(),
    )

    fields = mod.load_metadata_fields(
        bucket,
        'acme/app/99/1/4242.log',
        {'metadata_key': 'metadata/custom.fields'},
    )

    assert fields == {
        'workflow_job_id': 4242,
        'repository_full_name': 'acme/app',
        'workflow_job_conclusion': 'success',
    }


def test_wrap_line_merges_tags_and_metadata_fields(monkeypatch, aws):
    mod = _load_splunk(monkeypatch)

    wrapped = mod.wrap_line(
        '2026-07-03T22:26:04.000Z hello',
        1783117564.0,
        'forge-gh-logs',
        'acme/app/99/1/4242.log',
        {'runner_name': 'forge-runner-1', 'conclusion': 'success'},
        {'workflow_job_id': 4242, 'repository_full_name': 'acme/app'},
    )

    event = json.loads(wrapped)
    assert event['fields']['AccountId'] == '123456789012'
    assert event['fields']['runner_name'] == 'forge-runner-1'
    assert event['fields']['conclusion'] == 'success'
    assert event['fields']['workflow_job_id'] == 4242
    assert event['fields']['repository_full_name'] == 'acme/app'
