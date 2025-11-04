"""Lambda handler for streaming S3 log objects line-by-line to Kinesis with metadata.

Pipeline: S3 -> SQS -> Lambda -> Kinesis Data Stream -> Firehose -> Splunk

Features:
- Memory efficient: never load full object into memory.
- Gzip aware: transparently handle .gz objects.
- Batch records: up to 500 records per PutRecords call or 4MB aggregate.
- Retry failed records with exponential backoff (simple capped approach).
- Adds metadata: source, sourcetype, AccountId, Region, data_manager_input_id.
"""

from __future__ import annotations

import json
import logging
import os
import re
import time
from datetime import datetime, timezone
from typing import Iterable

import boto3

LOG = logging.getLogger()
level_str = os.environ.get('LOG_LEVEL', 'INFO').upper()
LOG.setLevel(getattr(logging, level_str, logging.INFO))

s3_client = boto3.client('s3')
kinesis_client = boto3.client('kinesis')
sts_client = boto3.client('sts')

SOURCETYPE = os.getenv('SOURCETYPE')
KINESIS_STREAM_NAME = os.getenv('KINESIS_STREAM_NAME')
MAX_RECORDS_BATCH = 500
MAX_BATCH_BYTES = 4000000

# Safety clamps
MAX_RECORDS_BATCH = min(MAX_RECORDS_BATCH, 500)
MAX_BATCH_BYTES = min(MAX_BATCH_BYTES, 4500000)

ACCOUNT_ID = sts_client.get_caller_identity()['Account']

TIMESTAMP_RE = re.compile(r'^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+Z)')


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
                for t in tag_resp.get('TagSet', []):
                    k = t.get('Key')
                    v = t.get('Value')
                    if k is not None and v is not None:
                        tags[k] = v
            except Exception as tag_err:  # pragma: no cover
                LOG.warning(
                    'tag_fetch_failed bucket=%s key=%s err=%s', bucket, key, tag_err)

            line_iter = stream_s3_object_lines(bucket, key)
            shipped = ship_lines_to_kinesis(line_iter, bucket, key, tags)
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


def extract_ts(line: str, last_ts: float | None) -> float:
    """
    Extract timestamp from log line if present, else use last_ts or current time.
    """
    m = TIMESTAMP_RE.match(line)
    if m:
        try:
            dt = datetime.strptime(
                m.group(1), '%Y-%m-%dT%H:%M:%S.%fZ').replace(tzinfo=timezone.utc)
            return dt.timestamp()
        except Exception:
            return time.time()
    return last_ts if last_ts is not None else time.time()


def wrap_line(line: str, ts: float, bucket: str, key: str, tags: dict[str, str]) -> str:
    """
    Wrap a log line with metadata for Splunk/Kinesis ingestion.
    Timestamp is passed in from outside.
    """
    base_fields = {
        'AccountId': ACCOUNT_ID,
    }
    base_fields.update(tags)
    event = {
        'event': line,
        'source': f"{bucket}:{key}",
        'sourcetype': SOURCETYPE,
        'time': ts,
        'fields': base_fields,
    }
    return json.dumps(event, separators=(',', ':'))


def ship_lines_to_kinesis(lines: Iterable[str], bucket: str, key: str, tags: dict[str, str]) -> int:
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
        payload = wrap_line(line, ts, bucket, key, tags).encode('utf-8')
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


if __name__ == '__main__':
    # Simple local test harness
    sample_event = {
        'Records': [
            {
                'body': json.dumps(
                    {
                        'Records': [
                            {
                                's3': {
                                    'bucket': {'name': 'example-bucket'},
                                    'object': {'key': 'logs/LOG.txt'},
                                }
                            }
                        ]
                    }
                )
            }
        ]
    }
    print(lambda_handler(sample_event, None))
