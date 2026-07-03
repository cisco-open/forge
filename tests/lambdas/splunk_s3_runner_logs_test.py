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


def test_load_metadata_fields_missing_sidecar_is_empty(monkeypatch, s3_kms):
    mod = _load_splunk(monkeypatch)
    bucket = s3_kms['buckets']['alpha']

    assert mod.load_metadata_fields(bucket, 'acme/app/99/1/4242.log') == {}


def test_load_metadata_fields_invalid_json_is_empty(monkeypatch, s3_kms):
    mod = _load_splunk(monkeypatch)
    bucket = s3_kms['buckets']['alpha']
    s3_kms['s3'].put_object(
        Bucket=bucket,
        Key='acme/app/99/1/4242.fields',
        Body=b'{not-json',
    )

    assert mod.load_metadata_fields(bucket, 'acme/app/99/1/4242.log') == {}


def test_normalize_metadata_fields_keeps_only_flat_scalars(monkeypatch, aws):
    mod = _load_splunk(monkeypatch)

    fields = mod.normalize_metadata_fields({
        'repository_full_name': 'acme/app',
        'workflow_job_id': 4242,
        'retry': False,
        'duration': 12.5,
        'nested': {'value': 'ignored'},
        'items': ['ignored'],
        'none': None,
        '': 'ignored',
        1: 'ignored',
    })

    assert fields == {
        'repository_full_name': 'acme/app',
        'workflow_job_id': 4242,
        'retry': False,
        'duration': 12.5,
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


def test_ship_lines_retries_only_failed_kinesis_records(monkeypatch, aws):
    mod = _load_splunk(monkeypatch)
    calls = []
    responses = [
        {
            'FailedRecordCount': 1,
            'Records': [
                {'SequenceNumber': '1'},
                {'ErrorCode': 'ProvisionedThroughputExceededException'},
            ],
        },
        {'FailedRecordCount': 0, 'Records': [{'SequenceNumber': '2'}]},
    ]

    class _Kinesis:
        def put_records(self, **kwargs):
            calls.append(kwargs)
            return responses.pop(0)

    monkeypatch.setattr(mod, 'kinesis_client', _Kinesis())
    monkeypatch.setattr(mod.time, 'sleep', lambda _seconds: None)

    shipped = mod.ship_lines_to_kinesis(
        ['2026-07-03T22:26:04.000Z one', 'continued'],
        'forge-gh-logs',
        'acme/app/99/1/4242.log',
        {'runner_name': 'forge-runner-1'},
        {'workflow_job_id': 4242},
    )

    assert shipped == 2
    assert len(calls) == 2
    assert len(calls[0]['Records']) == 2
    assert len(calls[1]['Records']) == 1


def test_ship_lines_skips_oversized_payload(monkeypatch, aws):
    mod = _load_splunk(monkeypatch)
    calls = []

    class _Kinesis:
        def put_records(self, **kwargs):
            calls.append(kwargs)
            return {'FailedRecordCount': 0, 'Records': []}

    monkeypatch.setattr(mod, 'kinesis_client', _Kinesis())

    shipped = mod.ship_lines_to_kinesis(
        ['x' * 1_000_000],
        'forge-gh-logs',
        'acme/app/99/1/4242.log',
        {},
    )

    assert shipped == 0
    assert calls == []


def test_lambda_handler_streams_log_lines_with_sidecar_fields(
    monkeypatch, s3_kms
):
    mod = _load_splunk(monkeypatch)
    bucket = s3_kms['buckets']['alpha']
    s3 = s3_kms['s3']
    log_key = 'acme/app/99/1/4242.log'
    metadata_key = 'metadata/custom.fields'
    records = []

    class _Kinesis:
        def put_records(self, **kwargs):
            records.extend(kwargs['Records'])
            return {
                'FailedRecordCount': 0,
                'Records': [{} for _record in kwargs['Records']],
            }

    monkeypatch.setattr(mod, 'kinesis_client', _Kinesis())

    s3.put_object(
        Bucket=bucket,
        Key=log_key,
        Body=b'2026-07-03T22:26:04.000Z one\ncontinued\n',
    )
    s3.put_object_tagging(
        Bucket=bucket,
        Key=log_key,
        Tagging={
            'TagSet': [
                {'Key': 'metadata_key', 'Value': metadata_key},
                {'Key': 'runner_name', 'Value': 'forge-runner-1'},
            ],
        },
    )
    s3.put_object(
        Bucket=bucket,
        Key=metadata_key,
        Body=json.dumps({
            'fields': {
                'workflow_job_id': 4242,
                'repository_full_name': 'acme/app',
            },
        }).encode(),
    )
    event = {
        'Records': [
            {
                'body': json.dumps({
                    'Records': [
                        {
                            's3': {
                                'bucket': {'name': bucket},
                                'object': {'key': log_key},
                            },
                        }
                    ],
                }),
            }
        ],
    }

    result = mod.lambda_handler(event, None)

    assert json.loads(result['body']) == {'lines': 2}
    assert len(records) == 2
    first = json.loads(records[0]['Data'].decode())
    assert first['fields']['workflow_job_id'] == 4242
    assert first['fields']['repository_full_name'] == 'acme/app'
    assert first['fields']['runner_name'] == 'forge-runner-1'
