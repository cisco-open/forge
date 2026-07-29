from __future__ import annotations

import json
from pathlib import Path

import pytest
from conftest import requires_aws
from support import load_handler_module

pytestmark = requires_aws
FIXTURES_DIR = Path(__file__).with_name('fixtures')


def _load_splunk(monkeypatch):
    monkeypatch.setenv('KINESIS_STREAM_NAME', 'splunk-runner-logs-test')
    monkeypatch.setenv(
        'SQS_QUEUE_URL',
        'https://sqs.us-west-2.amazonaws.com/123456789012/runner-logs',
    )
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


def test_load_metadata_fields_reads_github_metadata_file_shape(
    monkeypatch, s3_kms
):
    mod = _load_splunk(monkeypatch)
    bucket = s3_kms['buckets']['alpha']
    s3 = s3_kms['s3']
    metadata_key = 'metadata/987654321.fields'
    fixture_path = FIXTURES_DIR / 'splunk_s3_runner_logs_metadata_sidecar.json'
    payload = json.loads(fixture_path.read_text(encoding='utf-8'))

    s3.put_object(
        Bucket=bucket,
        Key=metadata_key,
        Body=fixture_path.read_bytes(),
    )

    fields = mod.load_metadata_fields(
        bucket,
        payload['source_log_key'],
        {'metadata_key': metadata_key},
    )

    assert fields == payload['fields']
    assert len(fields) == payload['field_count']
    assert 'source_log_key' not in fields
    assert 'source_event_key' not in fields


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
    assert calls[0]['Records'][1]['PartitionKey'] == (
        calls[1]['Records'][0]['PartitionKey']
    )


def test_ship_lines_uses_unique_partition_keys_across_batches(
    monkeypatch, aws
):
    mod = _load_splunk(monkeypatch)
    calls = []

    class _Kinesis:
        def put_records(self, **kwargs):
            calls.append(kwargs)
            return {
                'FailedRecordCount': 0,
                'Records': [{} for _record in kwargs['Records']],
            }

    monkeypatch.setattr(mod, 'kinesis_client', _Kinesis())
    monkeypatch.setattr(mod, 'MAX_RECORDS_BATCH', 2)

    shipped = mod.ship_lines_to_kinesis(
        [
            '2026-07-03T22:26:04.000Z one',
            'continued two',
            'continued three',
            'continued four',
        ],
        'forge-gh-logs',
        'acme/app/99/1/4242.log',
        {},
    )

    partition_keys = [
        record['PartitionKey']
        for call in calls
        for record in call['Records']
    ]

    assert shipped == 4
    assert len(calls) == 2
    assert len(partition_keys) == len(set(partition_keys))


def test_ship_lines_raises_when_kinesis_retries_are_exhausted(
    monkeypatch, aws, caplog
):
    mod = _load_splunk(monkeypatch)
    calls = []

    class _Kinesis:
        def put_records(self, **kwargs):
            calls.append(kwargs)
            return {
                'FailedRecordCount': 1,
                'Records': [{
                    'ErrorCode': 'ProvisionedThroughputExceededException',
                    'ErrorMessage': 'Rate exceeded for shard shardId-000',
                }],
            }

    monkeypatch.setattr(mod, 'kinesis_client', _Kinesis())
    monkeypatch.setattr(mod.time, 'sleep', lambda _seconds: None)

    with pytest.raises(
        RuntimeError,
        match='Kinesis rejected 1 runner-log records after 4 attempts',
    ):
        mod.ship_lines_to_kinesis(
            ['2026-07-03T22:26:04.000Z one'],
            'forge-gh-logs',
            'acme/app/99/1/4242.log',
            {},
        )

    assert len(calls) == 4
    assert 'ProvisionedThroughputExceededException' in caplog.text
    assert 'shardId-000' in caplog.text


def test_ship_lines_splits_oversized_log_line(monkeypatch, aws):
    mod = _load_splunk(monkeypatch)
    records = []

    class _Kinesis:
        def put_records(self, **kwargs):
            records.extend(kwargs['Records'])
            return {
                'FailedRecordCount': 0,
                'Records': [{} for _record in kwargs['Records']],
            }

    monkeypatch.setattr(mod, 'kinesis_client', _Kinesis())
    monkeypatch.setattr(mod, 'MAX_KINESIS_RECORD_BYTES', 1000)
    monkeypatch.setattr(mod, 'LONG_LINE_RECORD_TARGET_BYTES', 800)

    line = 'x' * 2000
    shipped = mod.ship_lines_to_kinesis(
        [line],
        'forge-gh-logs',
        'acme/app/99/1/4242.log',
        {'chunked': 'overridden-by-internal-field'},
    )

    events = [json.loads(record['Data'].decode()) for record in records]
    event_ids = {event['fields']['forge_event_id'] for event in events}
    partition_keys = [record['PartitionKey'] for record in records]

    assert shipped == len(records)
    assert len(records) > 1
    assert ''.join(event['event'] for event in events) == line
    assert len(event_ids) == 1
    assert partition_keys == [
        mod.partition_key_for_line(
            'forge-gh-logs',
            'acme/app/99/1/4242.log',
            0,
            chunk_index,
        )
        for chunk_index in range(len(records))
    ]
    assert len(partition_keys) == len(set(partition_keys))
    assert all(len(record['Data']) <= 800 for record in records)
    assert [
        event['fields']['chunk_index'] for event in events
    ] == list(range(len(events)))
    assert all(
        all((
            event['fields']['chunked'] == 'true',
            event['fields']['chunk_count'] == len(events),
            event['fields']['original_line_bytes'] == len(line.encode()),
        ))
        for event in events
    )


def test_ship_lines_splits_unicode_without_corrupting_raw_event(
    monkeypatch, aws
):
    mod = _load_splunk(monkeypatch)
    records = []

    class _Kinesis:
        def put_records(self, **kwargs):
            records.extend(kwargs['Records'])
            return {
                'FailedRecordCount': 0,
                'Records': [{} for _record in kwargs['Records']],
            }

    monkeypatch.setattr(mod, 'kinesis_client', _Kinesis())
    monkeypatch.setattr(mod, 'MAX_KINESIS_RECORD_BYTES', 1000)
    monkeypatch.setattr(mod, 'LONG_LINE_RECORD_TARGET_BYTES', 800)

    line = '🙂\\"' * 500
    shipped = mod.ship_lines_to_kinesis(
        [line],
        'forge-gh-logs',
        'acme/app/99/1/4242.log',
        {},
    )

    events = [json.loads(record['Data'].decode()) for record in records]

    assert shipped == len(records)
    assert len(records) > 1
    assert ''.join(event['event'] for event in events) == line
    assert all(len(record['Data']) <= 800 for record in records)
    assert all(
        event['fields']['original_line_bytes'] == len(line.encode('utf-8'))
        for event in events
    )


def test_read_s3_object_line_chunk_preserves_line_boundaries(
    monkeypatch, s3_kms
):
    mod = _load_splunk(monkeypatch)
    bucket = s3_kms['buckets']['alpha']
    key = 'acme/app/99/1/line-boundaries.log'
    payload = b'one\ntwo-long\nthree'
    s3_kms['s3'].put_object(Bucket=bucket, Key=key, Body=payload)

    first_lines, first_offset = mod.read_s3_object_line_chunk(
        bucket,
        key,
        0,
        5,
    )
    second_lines, final_offset = mod.read_s3_object_line_chunk(
        bucket,
        key,
        first_offset,
        5,
    )

    assert first_lines == ['one', 'two-long']
    assert first_offset == len(b'one\ntwo-long\n')
    assert second_lines == ['three']
    assert final_offset == len(payload)


def test_lambda_handler_checkpoints_large_log_after_successful_chunk(
    monkeypatch, s3_kms, caplog
):
    mod = _load_splunk(monkeypatch)
    bucket = s3_kms['buckets']['alpha']
    key = 'acme/app/99/1/checkpoint.log'
    payload = (
        b'2026-07-03T22:26:04.000Z one\n'
        b'continued second\n'
        b'continued third\n'
    )
    kinesis_events = []
    kinesis_timestamps = []
    checkpoint_messages = []

    class _Kinesis:
        def put_records(self, **kwargs):
            for record in kwargs['Records']:
                event = json.loads(record['Data'].decode())
                kinesis_events.append(event['event'])
                kinesis_timestamps.append(event['time'])
            return {
                'FailedRecordCount': 0,
                'Records': [{} for _record in kwargs['Records']],
            }

    class _SQS:
        def send_message(self, **kwargs):
            checkpoint_messages.append(json.loads(kwargs['MessageBody']))
            return {'MessageId': 'checkpoint-1'}

    monkeypatch.setattr(mod, 'kinesis_client', _Kinesis())
    monkeypatch.setattr(mod, 'sqs_client', _SQS())
    monkeypatch.setattr(mod, 'LOG_CHUNK_BYTES', 10)
    s3_kms['s3'].put_object(Bucket=bucket, Key=key, Body=payload)

    initial_event = {
        'Records': [{
            'messageId': 'source-message-1',
            'attributes': {'ApproximateReceiveCount': '1'},
            'body': json.dumps({
                'Records': [{
                    's3': {
                        'bucket': {'name': bucket},
                        'object': {'key': key, 'size': len(payload)},
                    },
                }],
            }),
        }],
    }

    initial_result = mod.lambda_handler(initial_event, None)

    assert json.loads(initial_result['body']) == {'lines': 1}
    assert (
        'sqs_message_received message_id=source-message-1 receive_count=1'
        in caplog.text
    )
    assert (
        'processing_object message_id=source-message-1 receive_count=1'
        in caplog.text
    )
    assert (
        'object_checkpoint_enqueued parent_message_id=source-message-1 '
        'message_id=checkpoint-1'
        in caplog.text
    )
    assert kinesis_events == ['2026-07-03T22:26:04.000Z one']
    assert len(checkpoint_messages) == 1
    checkpoint = checkpoint_messages.pop()
    checkpoint_data = checkpoint[mod.CHECKPOINT_FIELD]
    assert checkpoint_data == {
        'version': 1,
        'bucket': bucket,
        'key': key,
        'offset': len(b'2026-07-03T22:26:04.000Z one\n'),
        'object_size': len(payload),
        'last_timestamp': 1783117564.0,
    }

    continuation_lines = 0
    while True:
        continuation_result = mod.lambda_handler(
            {
                'Records': [{
                    'messageId': 'checkpoint-1',
                    'attributes': {'ApproximateReceiveCount': '1'},
                    'body': json.dumps(checkpoint),
                }],
            },
            None,
        )
        continuation_lines += json.loads(continuation_result['body'])['lines']
        if not checkpoint_messages:
            break
        checkpoint = checkpoint_messages.pop()

    assert continuation_lines == 2
    assert kinesis_events == [
        '2026-07-03T22:26:04.000Z one',
        'continued second',
        'continued third',
    ]
    assert kinesis_timestamps == [1783117564.0] * 3
    assert checkpoint_messages == []
    assert (
        'sqs_message_received message_id=checkpoint-1 receive_count=1'
        in caplog.text
    )
    assert (
        'processing_object message_id=checkpoint-1 receive_count=1'
        in caplog.text
    )


def test_lambda_handler_logs_sqs_retry_identity(monkeypatch, aws, caplog):
    mod = _load_splunk(monkeypatch)
    checkpoint_calls = []
    checkpoint = {
        'version': 1,
        'bucket': 'forge-gh-logs',
        'key': 'acme/app/99/1/retry.log',
        'offset': 1024,
        'object_size': 2048,
        'last_timestamp': None,
    }

    def _process_checkpoint(*args, **kwargs):
        checkpoint_calls.append((args, kwargs))
        return 0

    monkeypatch.setattr(mod, 'process_log_checkpoint', _process_checkpoint)
    monkeypatch.setattr(mod.time, 'time', lambda: 2000.0)

    result = mod.lambda_handler(
        {
            'Records': [{
                'messageId': 'retried-message-1',
                'attributes': {
                    'ApproximateReceiveCount': '3',
                    'SentTimestamp': '1990000',
                },
                'body': json.dumps({mod.CHECKPOINT_FIELD: checkpoint}),
            }],
        },
        None,
    )

    assert json.loads(result['body']) == {'lines': 0}
    assert result['batchItemFailures'] == []
    assert (
        'sqs_message_received message_id=retried-message-1 receive_count=3 '
        'sent_timestamp=1990000 age_seconds=10.000'
        in caplog.text
    )
    assert checkpoint_calls == [(
        (checkpoint,),
        {
            'sqs_message_id': 'retried-message-1',
            'sqs_receive_count': '3',
        },
    )]


def test_lambda_handler_reports_invalid_json_as_batch_failure(
    monkeypatch, aws, caplog
):
    mod = _load_splunk(monkeypatch)

    result = mod.lambda_handler(
        {
            'Records': [{
                'messageId': 'invalid-json-message',
                'attributes': {
                    'ApproximateReceiveCount': '2',
                    'SentTimestamp': 'invalid',
                },
                'body': '{not-json',
            }],
        },
        None,
    )

    assert json.loads(result['body']) == {'lines': 0}
    assert result['batchItemFailures'] == [{
        'itemIdentifier': 'invalid-json-message',
    }]
    assert (
        'sqs_message_failed message_id=invalid-json-message receive_count=2 '
        'sent_timestamp=invalid age_seconds=unknown'
        in caplog.text
    )


def test_lambda_handler_reports_json_ingestion_failure(
    monkeypatch, s3_kms, caplog
):
    mod = _load_splunk(monkeypatch)
    bucket = s3_kms['buckets']['alpha']
    key = 'acme/app/99/1/failed.json'
    s3_kms['s3'].put_object(Bucket=bucket, Key=key, Body=b'{"ok":true}')

    def _fail_shipping(*_args, **_kwargs):
        raise RuntimeError('Kinesis unavailable')

    monkeypatch.setattr(mod, 'ship_lines_to_kinesis', _fail_shipping)

    result = mod.lambda_handler(
        {
            'Records': [{
                'messageId': 'failed-json-message',
                'attributes': {'ApproximateReceiveCount': '1'},
                'body': json.dumps({
                    'Records': [{
                        's3': {
                            'bucket': {'name': bucket},
                            'object': {'key': key},
                        },
                    }],
                }),
            }],
        },
        None,
    )

    assert json.loads(result['body']) == {'lines': 0}
    assert result['batchItemFailures'] == [{
        'itemIdentifier': 'failed-json-message',
    }]
    assert 'json_object_failed' in caplog.text
    assert (
        'sqs_message_failed message_id=failed-json-message receive_count=1'
        in caplog.text
    )


def test_process_s3_object_does_not_checkpoint_failed_chunk(
    monkeypatch, s3_kms
):
    mod = _load_splunk(monkeypatch)
    bucket = s3_kms['buckets']['alpha']
    key = 'acme/app/99/1/failed-chunk.log'
    payload = b'first line\nsecond line\n'
    checkpoint_messages = []

    class _SQS:
        def send_message(self, **kwargs):
            checkpoint_messages.append(kwargs)
            return {'MessageId': 'unexpected'}

    def _fail_shipping(*_args, **_kwargs):
        raise RuntimeError('Kinesis unavailable')

    monkeypatch.setattr(mod, 'sqs_client', _SQS())
    monkeypatch.setattr(mod, 'ship_lines_to_kinesis', _fail_shipping)
    monkeypatch.setattr(mod, 'LOG_CHUNK_BYTES', 5)
    s3_kms['s3'].put_object(Bucket=bucket, Key=key, Body=payload)

    with pytest.raises(RuntimeError, match='Kinesis unavailable'):
        mod.process_s3_object(
            bucket,
            key,
            object_size=len(payload),
        )

    assert checkpoint_messages == []


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
