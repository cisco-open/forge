import hashlib
import json
import logging
import os
import re
import time
from datetime import datetime, timezone
from typing import Any, Iterable

import boto3
from botocore.exceptions import ClientError

LOG = logging.getLogger()
level_str = os.environ.get('LOG_LEVEL', 'INFO').upper()
LOG.setLevel(getattr(logging, level_str, logging.INFO))

s3_client = boto3.client('s3')
kinesis_client = boto3.client('kinesis')
sqs_client = boto3.client('sqs')
sts_client = boto3.client('sts')

SOURCETYPE = os.getenv('SOURCETYPE')
INDEX = os.getenv('INDEX')
KINESIS_STREAM_NAME = os.getenv('KINESIS_STREAM_NAME')
SQS_QUEUE_URL = os.getenv('SQS_QUEUE_URL')
LOG_CHUNK_BYTES = int(os.getenv('LOG_CHUNK_BYTES', str(8 * 1024 * 1024)))
MAX_RECORDS_BATCH = 500
MAX_BATCH_BYTES = 4000000
MAX_KINESIS_RECORD_BYTES = 1000000
LONG_LINE_RECORD_TARGET_BYTES = 750 * 1024
CHECKPOINT_FIELD = 'forge_runner_log_checkpoint'
CHECKPOINT_VERSION = 1

# Safety clamps
MAX_RECORDS_BATCH = min(MAX_RECORDS_BATCH, 500)
MAX_BATCH_BYTES = min(MAX_BATCH_BYTES, 4500000)

ACCOUNT_ID = sts_client.get_caller_identity()['Account']

TIMESTAMP_RE = re.compile(r'^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+Z)')
METADATA_SUFFIX = '.fields'
METADATA_TAG_KEY = 'metadata_key'


def lambda_handler(event, _context):
    """Entry point for Lambda: processes SQS event containing S3 notifications."""
    records = event.get('Records', [])
    if not records:
        LOG.info('lambda_no_records')
        return {
            'statusCode': 200,
            'body': 'No messages',
            'batchItemFailures': [],
        }

    total_lines = 0
    batch_item_failures = []
    for r in records:
        message_id = r.get('messageId') or 'unknown'
        attributes = r.get('attributes', {})
        receive_count = attributes.get('ApproximateReceiveCount') or 'unknown'
        sent_timestamp = attributes.get('SentTimestamp') or 'unknown'
        message_age_seconds = sqs_message_age_seconds(sent_timestamp)
        LOG.info(
            'sqs_message_received message_id=%s receive_count=%s '
            'sent_timestamp=%s age_seconds=%s',
            message_id,
            receive_count,
            sent_timestamp,
            (
                f'{message_age_seconds:.3f}'
                if message_age_seconds is not None
                else 'unknown'
            ),
        )
        try:
            body = r.get('body')
            if not body:
                raise ValueError('SQS message body is empty')
            body_json = json.loads(body)
            checkpoint = body_json.get(CHECKPOINT_FIELD)
            if checkpoint is not None:
                total_lines += process_log_checkpoint(
                    checkpoint,
                    sqs_message_id=message_id,
                    sqs_receive_count=receive_count,
                )
                continue

            s3_records = body_json.get('Records')
            if not isinstance(s3_records, list) or not s3_records:
                raise ValueError('SQS message contains no S3 records')

            for s3_rec in s3_records:
                bucket = s3_rec.get('s3', {}).get('bucket', {}).get('name')
                object_data = s3_rec.get('s3', {}).get('object', {})
                key = object_data.get('key')
                object_size = object_data.get('size')
                if not bucket or not key:
                    raise ValueError(
                        'S3 notification is missing bucket or key')
                total_lines += process_s3_object(
                    bucket,
                    key,
                    object_size=object_size,
                    sqs_message_id=message_id,
                    sqs_receive_count=receive_count,
                )
        except Exception as err:  # noqa: BLE001
            LOG.exception(
                'sqs_message_failed message_id=%s receive_count=%s '
                'sent_timestamp=%s age_seconds=%s err=%s',
                message_id,
                receive_count,
                sent_timestamp,
                (
                    f'{message_age_seconds:.3f}'
                    if message_age_seconds is not None
                    else 'unknown'
                ),
                err,
            )
            batch_item_failures.append({'itemIdentifier': message_id})
            continue

    return {
        'statusCode': 200,
        'body': json.dumps({'lines': total_lines}),
        'batchItemFailures': batch_item_failures,
    }


def sqs_message_age_seconds(sent_timestamp: str) -> float | None:
    """Return the non-negative age of an SQS message from SentTimestamp."""
    try:
        sent_timestamp_seconds = int(sent_timestamp) / 1000
    except (TypeError, ValueError):
        return None
    return max(0.0, time.time() - sent_timestamp_seconds)


def process_s3_object(
    bucket: str,
    key: str,
    *,
    object_size: int | None = None,
    start_offset: int = 0,
    last_timestamp: float | None = None,
    sqs_message_id: str = 'unknown',
    sqs_receive_count: str = 'unknown',
) -> int:
    """Process a JSON object or one bounded, line-aligned log chunk."""
    LOG.info(
        'processing_object message_id=%s receive_count=%s '
        'bucket=%s key=%s offset=%d',
        sqs_message_id,
        sqs_receive_count,
        bucket,
        key,
        start_offset,
    )
    tags = load_object_tags(bucket, key)
    metadata_fields = load_metadata_fields(bucket, key, tags)

    if key.endswith('.json'):
        if start_offset != 0:
            raise ValueError('JSON objects do not support checkpoint offsets')
        try:
            obj = s3_client.get_object(Bucket=bucket, Key=key)
            raw = obj['Body'].read()
            text = raw.decode('utf-8', errors='replace')
            shipped = ship_lines_to_kinesis(
                [text], bucket, key, tags, metadata_fields)
            LOG.info(
                'json_object_ingested bucket=%s key=%s size=%d',
                bucket,
                key,
                len(raw),
            )
        except Exception as json_err:  # pragma: no cover
            LOG.exception(
                'json_object_failed bucket=%s key=%s err=%s',
                bucket,
                key,
                json_err,
            )
            raise
        LOG.info('object_complete bucket=%s key=%s lines=%d',
                 bucket, key, shipped)
        return shipped

    if not key.endswith('.log'):
        LOG.info('unsupported_object_skip bucket=%s key=%s', bucket, key)
        return 0

    if object_size is None:
        object_size = s3_client.head_object(
            Bucket=bucket,
            Key=key,
        )['ContentLength']
    object_size = int(object_size)
    if start_offset < 0 or start_offset > object_size:
        raise ValueError(
            f'Invalid checkpoint offset {start_offset} for size {object_size}'
        )
    if start_offset == object_size:
        LOG.info('object_complete bucket=%s key=%s lines=0', bucket, key)
        return 0

    lines, next_offset = read_s3_object_line_chunk(
        bucket,
        key,
        start_offset,
        LOG_CHUNK_BYTES,
    )
    shipped = ship_lines_to_kinesis(
        lines,
        bucket,
        key,
        tags,
        metadata_fields,
        line_number_start=start_offset,
        initial_last_ts=last_timestamp,
    )
    last_timestamp = timestamp_after_lines(lines, last_timestamp)
    LOG.info(
        'object_chunk_complete message_id=%s receive_count=%s '
        'bucket=%s key=%s offset=%d next_offset=%d size=%d lines=%d',
        sqs_message_id,
        sqs_receive_count,
        bucket,
        key,
        start_offset,
        next_offset,
        object_size,
        shipped,
    )

    if next_offset < object_size:
        enqueue_log_checkpoint(
            bucket,
            key,
            next_offset,
            object_size,
            last_timestamp,
            parent_message_id=sqs_message_id,
        )
    else:
        LOG.info('object_complete bucket=%s key=%s lines=%d',
                 bucket, key, shipped)
    return shipped


def process_log_checkpoint(
    checkpoint: Any,
    *,
    sqs_message_id: str = 'unknown',
    sqs_receive_count: str = 'unknown',
) -> int:
    """Validate and process a continuation message from the runner-log queue."""
    if not isinstance(checkpoint, dict):
        raise ValueError('Runner-log checkpoint must be an object')
    if checkpoint.get('version') != CHECKPOINT_VERSION:
        raise ValueError('Unsupported runner-log checkpoint version')

    bucket = checkpoint.get('bucket')
    key = checkpoint.get('key')
    offset = checkpoint.get('offset')
    object_size = checkpoint.get('object_size')
    last_timestamp = checkpoint.get('last_timestamp')
    valid_bucket = isinstance(bucket, str) and bool(bucket)
    valid_key = isinstance(key, str) and key.endswith('.log')
    valid_offset = isinstance(offset, int) and not isinstance(offset, bool)
    valid_size = (
        isinstance(object_size, int) and not isinstance(object_size, bool)
    )
    timestamp_is_number = isinstance(last_timestamp, (int, float))
    timestamp_is_boolean = isinstance(last_timestamp, bool)
    valid_timestamp = last_timestamp is None or (
        timestamp_is_number and not timestamp_is_boolean
    )
    if not all((
        valid_bucket,
        valid_key,
        valid_offset,
        valid_size,
        valid_timestamp,
    )):
        raise ValueError('Invalid runner-log checkpoint')

    return process_s3_object(
        bucket,
        key,
        object_size=object_size,
        start_offset=offset,
        last_timestamp=last_timestamp,
        sqs_message_id=sqs_message_id,
        sqs_receive_count=sqs_receive_count,
    )


def enqueue_log_checkpoint(
    bucket: str,
    key: str,
    offset: int,
    object_size: int,
    last_timestamp: float | None,
    *,
    parent_message_id: str = 'unknown',
) -> None:
    """Enqueue the next byte offset after the current chunk is fully shipped."""
    if not SQS_QUEUE_URL:
        raise RuntimeError('SQS_QUEUE_URL is required for log checkpoints')
    body = {
        CHECKPOINT_FIELD: {
            'version': CHECKPOINT_VERSION,
            'bucket': bucket,
            'key': key,
            'offset': offset,
            'object_size': object_size,
            'last_timestamp': last_timestamp,
        },
    }
    response = sqs_client.send_message(
        QueueUrl=SQS_QUEUE_URL,
        MessageBody=json.dumps(body, separators=(',', ':')),
    )
    checkpoint_message_id = response.get('MessageId') or 'unknown'
    LOG.info(
        'object_checkpoint_enqueued parent_message_id=%s message_id=%s '
        'bucket=%s key=%s offset=%d size=%d',
        parent_message_id,
        checkpoint_message_id,
        bucket,
        key,
        offset,
        object_size,
    )


def load_object_tags(bucket: str, key: str) -> dict[str, str]:
    """Fetch scalar S3 object tags used as Splunk event fields."""
    tags: dict[str, str] = {}
    try:
        tag_resp = s3_client.get_object_tagging(Bucket=bucket, Key=key)
        tag_set = tag_resp.get('TagSet', [])
        LOG.debug('Fetched %d tags for bucket=%s key=%s',
                  len(tag_set), bucket, key)

        for idx, tag in enumerate(tag_set):
            tag_key = tag.get('Key')
            tag_value = tag.get('Value')
            if tag_key is not None and tag_value is not None:
                tags[tag_key] = tag_value
            else:
                LOG.warning(
                    'Skipped invalid tag[%d] bucket=%s key=%s tag=%s',
                    idx,
                    bucket,
                    key,
                    tag,
                )
    except Exception as tag_err:  # pragma: no cover
        LOG.warning(
            'tag_fetch_failed bucket=%s key=%s err=%s',
            bucket,
            key,
            tag_err,
        )
    return tags


def read_s3_object_line_chunk(
    bucket: str,
    key: str,
    start_offset: int,
    max_bytes: int,
) -> tuple[list[str], int]:
    """Read at least max_bytes and stop only after a complete log line."""
    if max_bytes < 1:
        raise ValueError('max_bytes must be positive')

    obj = s3_client.get_object(
        Bucket=bucket,
        Key=key,
        Range=f'bytes={start_offset}-',
    )
    body = obj['Body']
    buffer = b''
    lines: list[str] = []
    consumed = 0

    try:
        while True:
            chunk = body.read(64 * 1024)
            if not chunk:
                if buffer:
                    lines.append(buffer.decode('utf-8', errors='replace'))
                    consumed += len(buffer)
                return lines, start_offset + consumed

            buffer += chunk
            while b'\n' in buffer:
                raw_line, buffer = buffer.split(b'\n', 1)
                lines.append(raw_line.decode('utf-8', errors='replace'))
                consumed += len(raw_line) + 1
                if consumed >= max_bytes:
                    return lines, start_offset + consumed
    finally:
        body.close()


def stream_s3_object_lines(bucket: str, key: str) -> Iterable[str]:
    """Stream lines from an S3 object without loading the whole file."""
    obj = s3_client.get_object(Bucket=bucket, Key=key)
    body = obj['Body']

    buffer = ''
    chunk_size = 64 * 1024
    while True:
        chunk = body.read(chunk_size)
        if not chunk:
            break
        text = chunk.decode('utf-8', errors='replace')
        buffer += text
        lines = buffer.split('\n')
        yield from lines[:-1]
        buffer = lines[-1]
    if buffer:
        yield buffer


def metadata_key_for_object(key: str, tags: dict[str, str] | None = None) -> str:
    if tags:
        metadata_key = tags.get(METADATA_TAG_KEY)
        if metadata_key:
            return metadata_key

    if key.endswith('.json'):
        return f"{key[:-5]}{METADATA_SUFFIX}"
    if key.endswith('.log'):
        return f"{key[:-4]}{METADATA_SUFFIX}"
    return f"{key}{METADATA_SUFFIX}"


def normalize_metadata_fields(raw_fields: Any) -> dict[str, Any]:
    if not isinstance(raw_fields, dict):
        return {}

    fields: dict[str, Any] = {}
    for key, value in raw_fields.items():
        if not isinstance(key, str) or not key:
            continue
        if isinstance(value, (str, int, float, bool)):
            fields[key] = value
    return fields


def load_metadata_fields(
    bucket: str,
    key: str,
    tags: dict[str, str] | None = None,
) -> dict[str, Any]:
    metadata_key = metadata_key_for_object(key, tags)
    try:
        obj = s3_client.get_object(Bucket=bucket, Key=metadata_key)
        raw = obj['Body'].read()
    except ClientError as err:
        code = err.response.get('Error', {}).get('Code')
        if code in ('NoSuchKey', '404', 'NotFound'):
            LOG.info('metadata_sidecar_missing bucket=%s key=%s metadata_key=%s',
                     bucket, key, metadata_key)
        else:
            LOG.warning('metadata_sidecar_fetch_failed bucket=%s key=%s metadata_key=%s err=%s',
                        bucket, key, metadata_key, err)
        return {}
    except Exception as err:  # pragma: no cover
        LOG.warning('metadata_sidecar_fetch_failed bucket=%s key=%s metadata_key=%s err=%s',
                    bucket, key, metadata_key, err)
        return {}

    try:
        payload = json.loads(raw.decode('utf-8', errors='replace'))
    except json.JSONDecodeError as err:
        LOG.warning('metadata_sidecar_invalid_json bucket=%s key=%s metadata_key=%s err=%s',
                    bucket, key, metadata_key, err)
        return {}

    fields = normalize_metadata_fields(payload.get(
        'fields') if isinstance(payload, dict) else None)
    LOG.debug('metadata_sidecar_fields bucket=%s key=%s metadata_key=%s field_count=%d',
              bucket, key, metadata_key, len(fields))
    return fields


def extract_ts(line: str, last_ts: str | float | None) -> float:
    """
    Extract timestamp from a log line.
    - If the line has an ISO8601 timestamp, parse and return it.
    - Else, reuse `last_ts` from the previous line.
    - If no previous timestamp exists, use current system time.
    """
    def parse_iso8601(ts_str: str) -> float:
        if '.' in ts_str:
            base, frac = ts_str.rstrip('Z').split('.')
            frac = (frac + '000000')[:6]
            ts_str = f"{base}.{frac}Z"
        dt = datetime.strptime(ts_str, '%Y-%m-%dT%H:%M:%S.%fZ')
        return dt.replace(tzinfo=timezone.utc).timestamp()

    m = TIMESTAMP_RE.match(line)
    if m:
        try:
            return round(parse_iso8601(m.group(1)), 3)
        except Exception:
            pass
    if last_ts is not None:
        return last_ts
    return round(time.time(), 3)


def timestamp_after_lines(
    lines: Iterable[str],
    initial_last_ts: float | None,
) -> float | None:
    """Return the timestamp state that must continue with the next chunk."""
    last_ts = initial_last_ts
    for line in lines:
        if line:
            last_ts = extract_ts(line, last_ts)
    return last_ts


def wrap_line(
    line: str,
    ts: float,
    bucket: str,
    key: str,
    tags: dict[str, str],
    metadata_fields: dict[str, Any] | None = None,
    event_fields: dict[str, Any] | None = None,
) -> str:
    """
    Wrap a log line with metadata for Splunk/Kinesis ingestion.
    Timestamp is passed in from outside.
    """
    base_fields = {
        'AccountId': ACCOUNT_ID,
        **(metadata_fields or {}),
        **tags,
        **(event_fields or {}),
    }
    event = {
        'event': line,
        'source': f"{bucket}:{key}",
        'sourcetype': f"forgecicd:runner-logs:{'json' if key.endswith('.json') else 'logs'}",
        'time': ts,
        'fields': base_fields,
    }
    LOG.debug(
        'wrap_line_debug bucket=%s key=%s event=%s',
        bucket, key, event
    )
    return json.dumps(event) + '\n'


def split_long_log_line(
    line: str,
    ts: float,
    bucket: str,
    key: str,
    tags: dict[str, str],
    metadata_fields: dict[str, Any] | None,
    line_number: int,
) -> list[bytes]:
    """Split one oversized log line into UTF-8-safe HEC event payloads."""
    event_id = partition_key_for_line(bucket, key, line_number)
    original_line_bytes = len(line.encode('utf-8'))
    placeholder_fields = {
        'forge_event_id': event_id,
        'chunked': 'true',
        'chunk_index': 999999999,
        'chunk_count': 999999999,
        'original_line_bytes': original_line_bytes,
    }
    fragments: list[str] = []
    start = 0

    while start < len(line):
        low = start + 1
        high = len(line)
        best_end = start
        while low <= high:
            candidate_end = (low + high) // 2
            candidate = wrap_line(
                line[start:candidate_end],
                ts,
                bucket,
                key,
                tags,
                metadata_fields,
                placeholder_fields,
            ).encode('utf-8')
            if len(candidate) <= LONG_LINE_RECORD_TARGET_BYTES:
                best_end = candidate_end
                low = candidate_end + 1
            else:
                high = candidate_end - 1

        if best_end == start:
            raise RuntimeError(
                'Runner-log metadata exceeds the long-line record target'
            )
        fragments.append(line[start:best_end])
        start = best_end

    chunk_count = len(fragments)
    payloads = []
    for chunk_index, fragment in enumerate(fragments):
        chunk_fields = {
            'forge_event_id': event_id,
            'chunked': 'true',
            'chunk_index': chunk_index,
            'chunk_count': chunk_count,
            'original_line_bytes': original_line_bytes,
        }
        payload = wrap_line(
            fragment,
            ts,
            bucket,
            key,
            tags,
            metadata_fields,
            chunk_fields,
        ).encode('utf-8')
        if len(payload) > MAX_KINESIS_RECORD_BYTES:
            raise RuntimeError(
                f'Long-line chunk exceeds Kinesis limit: {len(payload)} bytes'
            )
        payloads.append(payload)

    LOG.info(
        'long_line_split bucket=%s key=%s event_id=%s '
        'original_bytes=%d chunks=%d',
        bucket,
        key,
        event_id,
        original_line_bytes,
        chunk_count,
    )
    return payloads


def ship_lines_to_kinesis(
    lines: Iterable[str],
    bucket: str,
    key: str,
    tags: dict[str, str],
    metadata_fields: dict[str, Any] | None = None,
    line_number_start: int = 0,
    initial_last_ts: float | None = None,
) -> int:
    """Batch lines into PutRecords requests respecting count & size limits."""
    buffer: list[tuple[bytes, int, str]] = []
    total_shipped = 0
    current_bytes = 0

    def flush():
        nonlocal buffer, total_shipped, current_bytes
        if not buffer:
            return
        records = [
            {'Data': data, 'PartitionKey': partition_key}
            for data, _length, partition_key in buffer
        ]
        attempt = 0
        failures: list[dict[str, Any]] = []
        while attempt < 4:
            resp = kinesis_client.put_records(
                StreamName=KINESIS_STREAM_NAME, Records=records)
            failed = resp.get('FailedRecordCount', 0)
            if failed == 0:
                total_shipped += len(buffer)
                break
            # retry failed records
            failures = [
                result
                for result in resp.get('Records', [])
                if 'ErrorCode' in result
            ]
            new_records = [
                rec
                for rec, result in zip(records, resp.get('Records', []))
                if 'ErrorCode' in result
            ]
            records = new_records
            attempt += 1
            backoff = 2 ** attempt * 0.25
            LOG.warning(
                'kinesis_put_retry failed=%d attempt=%d backoff=%.2f',
                failed,
                attempt,
                backoff,
            )
            time.sleep(backoff)
        else:
            LOG.error(
                'kinesis_put_failed_after_retries remaining=%d failures=%s',
                len(records),
                [
                    {
                        'error_code': failure.get('ErrorCode'),
                        'error_message': failure.get('ErrorMessage'),
                    }
                    for failure in failures
                ],
            )
            raise RuntimeError(
                f'Kinesis rejected {len(records)} runner-log records '
                'after 4 attempts'
            )
        buffer = []
        current_bytes = 0

    last_ts = initial_last_ts
    for line_number, line in enumerate(lines, start=line_number_start):
        if not line:
            continue
        ts = extract_ts(line, last_ts)
        last_ts = ts
        payload = wrap_line(
            line, ts, bucket, key, tags, metadata_fields).encode('utf-8')
        if len(payload) > MAX_KINESIS_RECORD_BYTES:
            if not key.endswith('.log'):
                raise RuntimeError(
                    'Oversized non-log runner event cannot be safely split'
                )
            payloads = split_long_log_line(
                line,
                ts,
                bucket,
                key,
                tags,
                metadata_fields,
                line_number,
            )
        else:
            payloads = [payload]

        for chunk_index, chunk_payload in enumerate(payloads):
            payload_len = len(chunk_payload)
            batch_is_full = len(buffer) >= MAX_RECORDS_BATCH
            batch_would_be_too_large = (
                current_bytes + payload_len >= MAX_BATCH_BYTES
            )
            if batch_is_full or batch_would_be_too_large:
                flush()
            buffer.append((
                chunk_payload,
                payload_len,
                partition_key_for_line(
                    bucket,
                    key,
                    line_number,
                    chunk_index if len(payloads) > 1 else None,
                ),
            ))
            current_bytes += payload_len

    flush()
    return total_shipped


def partition_key_for_line(
    bucket: str,
    key: str,
    line_number: int,
    chunk_index: int | None = None,
) -> str:
    """Return a stable, high-cardinality Kinesis partition key."""
    identity = f'{bucket}\0{key}\0{line_number}'
    if chunk_index is not None:
        identity = f'{identity}\0{chunk_index}'
    return hashlib.sha256(identity.encode()).hexdigest()
