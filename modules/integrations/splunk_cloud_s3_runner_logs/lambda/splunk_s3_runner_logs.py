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
sts_client = boto3.client('sts')

SOURCETYPE = os.getenv('SOURCETYPE')
INDEX = os.getenv('INDEX')
KINESIS_STREAM_NAME = os.getenv('KINESIS_STREAM_NAME')
MAX_RECORDS_BATCH = 500
MAX_BATCH_BYTES = 4000000

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
        return {'statusCode': 200, 'body': 'No messages'}

    total_lines = 0
    for r in records:
        body = r.get('body')
        if not body:
            continue
        try:
            body_json = json.loads(body)
        except json.JSONDecodeError:
            LOG.warning('invalid_json_body_skip')
            continue

        for s3_rec in body_json.get('Records', []):
            bucket = s3_rec.get('s3', {}).get('bucket', {}).get('name')
            key = s3_rec.get('s3', {}).get('object', {}).get('key')
            if not bucket or not key:
                LOG.warning('missing_bucket_or_key')
                continue
            LOG.info('processing_object bucket=%s key=%s', bucket, key)
            # Fetch object tags once per object
            tags: dict[str, str] = {}
            try:
                tag_resp = s3_client.get_object_tagging(Bucket=bucket, Key=key)
                tag_set = tag_resp.get('TagSet', [])
                LOG.debug('Fetched %d tags for bucket=%s key=%s',
                          len(tag_set), bucket, key)

                for idx, t in enumerate(tag_set):
                    k = t.get('Key')
                    v = t.get('Value')
                    LOG.debug(
                        'Processing tag[%d]: Key=%s, Value=%s', idx, k, v)
                    if k is not None and v is not None:
                        tags[k] = v
                    else:
                        LOG.warning(
                            'Skipped invalid tag[%d] bucket=%s key=%s tag=%s', idx, bucket, key, t)

                LOG.debug('Final object_tags bucket=%s key=%s tag_count=%d tags=%s',
                          bucket, key, len(tags), tags)
            except Exception as tag_err:  # pragma: no cover
                LOG.warning(
                    'tag_fetch_failed bucket=%s key=%s err=%s', bucket, key, tag_err)

            metadata_fields = load_metadata_fields(bucket, key, tags)

            # Decide ingestion strategy based on file type.
            if key.endswith('.json'):
                # Treat entire JSON file as a single event line.
                try:
                    obj = s3_client.get_object(Bucket=bucket, Key=key)
                    raw = obj['Body'].read()
                    text = raw.decode('utf-8', errors='replace')
                    shipped = ship_lines_to_kinesis(
                        [text], bucket, key, tags, metadata_fields)
                    LOG.info(
                        'json_object_ingested bucket=%s key=%s size=%d', bucket, key, len(raw))
                except Exception as json_err:  # pragma: no cover
                    LOG.warning(
                        'json_object_failed bucket=%s key=%s err=%s', bucket, key, json_err)
                    continue
            elif key.endswith('.log'):
                # Line-by-line streaming for log files.
                line_iter = stream_s3_object_lines(bucket, key)
                shipped = ship_lines_to_kinesis(
                    line_iter, bucket, key, tags, metadata_fields)
            else:
                LOG.info('unsupported_object_skip bucket=%s key=%s', bucket, key)
                continue
            total_lines += shipped
            LOG.info('object_complete bucket=%s key=%s lines=%d',
                     bucket, key, shipped)

    return {'statusCode': 200, 'body': json.dumps({'lines': total_lines})}


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


def wrap_line(
    line: str,
    ts: float,
    bucket: str,
    key: str,
    tags: dict[str, str],
    metadata_fields: dict[str, Any] | None = None,
) -> str:
    """
    Wrap a log line with metadata for Splunk/Kinesis ingestion.
    Timestamp is passed in from outside.
    """
    base_fields = {
        'AccountId': ACCOUNT_ID,
        **(metadata_fields or {}),
        **tags,
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


def ship_lines_to_kinesis(
    lines: Iterable[str],
    bucket: str,
    key: str,
    tags: dict[str, str],
    metadata_fields: dict[str, Any] | None = None,
) -> int:
    """Batch lines into PutRecords requests respecting count & size limits."""
    buffer: list[tuple[bytes, int]] = []  # (data_bytes, length)
    total_shipped = 0
    current_bytes = 0

    def flush():
        nonlocal buffer, total_shipped, current_bytes
        if not buffer:
            return
        records = [{'Data': b, 'PartitionKey': str(
            i)} for i, (b, _l) in enumerate(buffer)]
        attempt = 0
        while attempt < 4:
            resp = kinesis_client.put_records(
                StreamName=KINESIS_STREAM_NAME, Records=records)
            failed = resp.get('FailedRecordCount', 0)
            if failed == 0:
                total_shipped += len(buffer)
                break
            # retry failed records
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
                'kinesis_put_failed_after_retries remaining=%d', len(records))
        buffer = []
        current_bytes = 0

    last_ts: float | None = None
    for line in lines:
        if not line:
            continue
        ts = extract_ts(line, last_ts)
        last_ts = ts
        payload = wrap_line(
            line, ts, bucket, key, tags, metadata_fields).encode('utf-8')
        payload_len = len(payload)
        if payload_len > 1000000:  # Guard insanely long lines
            LOG.warning('line_too_large_skip size=%d', payload_len)
            continue
        if len(buffer) >= MAX_RECORDS_BATCH or (current_bytes + payload_len) >= MAX_BATCH_BYTES:
            flush()
        buffer.append((payload, payload_len))
        current_bytes += payload_len

    flush()
    return total_shipped
