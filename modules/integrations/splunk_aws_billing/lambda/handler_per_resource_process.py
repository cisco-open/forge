# -*- coding: utf-8 -*-
import calendar
import gzip
import io
import json
import os
import re
import time
from decimal import ROUND_HALF_UP, Decimal
from urllib.parse import unquote

import boto3
import pandas as pd
import requests

SPLUNK_HEC_URL = os.environ['SPLUNK_HEC_URL']
SPLUNK_HEC_TOKEN = os.environ['SPLUNK_HEC_TOKEN']
SPLUNK_INDEX = os.environ.get('SPLUNK_INDEX')
SPLUNK_METRICS_TOKEN = os.environ['SPLUNK_METRICS_TOKEN']
SPLUNK_METRICS_URL = os.environ['SPLUNK_METRICS_URL']

MAX_BATCH_SIZE_BYTES = 950_000
MAX_BATCH_COUNT = 500
METRICS_BATCH_SIZE = 500

s3 = boto3.client('s3')


def send_to_splunk_batch(events):
    if not events:
        return

    payload = '\n'.join(events)
    headers = {
        'Authorization': f'Splunk {SPLUNK_HEC_TOKEN}',
        'Content-Type': 'application/json',
        'Content-Encoding': 'gzip'
    }
    compressed_payload = gzip.compress(payload.encode())

    try:
        resp = requests.post(SPLUNK_HEC_URL, headers=headers,
                             data=compressed_payload, timeout=10)
        print(
            f'[Splunk Batch] Sent {len(events)} events | Status: {resp.status_code}')
        resp.raise_for_status()
    except requests.RequestException as e:
        print(f'[ERROR] Failed to send batch to Splunk: {e}')


def send_metric_to_o11y_batch(metrics):
    if not metrics:
        return

    payload = {
        'gauge': metrics
    }
    headers = {
        'X-SF-TOKEN': SPLUNK_METRICS_TOKEN,
        'Content-Type': 'application/json'
    }
    try:
        resp = requests.post(SPLUNK_METRICS_URL,
                             headers=headers, json=payload, timeout=10)
        print(
            f'[O11y Batch] Sent {len(metrics)} metrics | Status: {resp.status_code}')
        resp.raise_for_status()
    except requests.RequestException as e:
        print(f'[O11y ERROR] Failed to send metric batch: {e}')


def extract_arn_parts(arn):
    match = re.search(
        r'arn:aws:resource-groups:(?P<aws_region>[\w-]+):(?P<account_id>\d+):group/(?P<forgecicd_tenant>[^-]+)-(?P<forgecicd_region_alias>[^-]+)-(?P<forgecicd_vpc_alias>[^/]+)/',
        arn
    )
    if match:
        return match.groupdict()
    return {
        'aws_region': 'unknown',
        'account_id': 'unknown',
        'forgecicd_tenant': 'unknown',
        'forgecicd_region_alias': 'unknown',
        'forgecicd_vpc_alias': 'unknown'
    }


def preprocess_df(df):
    print(f'[INFO] Raw DataFrame shape: {df.shape}')
    df['ingest_time'] = pd.Timestamp.now(tz='UTC')

    key_cols = [
        'line_item_usage_start_date',
        'line_item_product_code',
        'user_aws_application',
        'line_item_resource_id',
        'identity_line_item_id'
    ]

    df = df.sort_values('ingest_time', ascending=False)
    df = df.drop_duplicates(subset=key_cols, keep='first')
    print(f'[INFO] Preprocessed DataFrame shape: {df.shape}')
    return df


def lambda_handler(event, context):
    print(f'[INFO] Lambda triggered with event: {json.dumps(event)}')

    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = unquote(record['s3']['object']['key'])

        print(f'[INFO] Processing file from bucket: {bucket}, key: {key}')
        obj = s3.get_object(Bucket=bucket, Key=key)
        df = pd.read_parquet(io.BytesIO(obj['Body'].read()))

        df = preprocess_df(df)

        grouped = df.groupby(
            ['usage_date', 'line_item_resource_id',
             'line_item_product_code', 'user_aws_application'],
            as_index=False
        ).agg({
            'line_item_unblended_cost': 'sum',
            'line_item_net_unblended_cost': 'sum'
        })

        print(f'[INFO] Grouped {len(grouped)} records for Splunk')

        now_ts = int(time.time())
        batch = []
        current_size = 0

        metrics_batch = []

        for _, row in grouped.iterrows():
            fields = extract_arn_parts(row['user_aws_application'])
            usage_date = str(row['usage_date'])
            event_time = calendar.timegm(
                pd.to_datetime(usage_date).timetuple())

            event_body = {
                'source': 'aws-cur-per-resource',
                'sourcetype': 'forgecicd:aws:billing:cur',
                'index': SPLUNK_INDEX,
                'event': {
                    'service': row['line_item_product_code'],
                    'resource_id': row['line_item_resource_id'],
                    'aws_application': row['user_aws_application'],
                    'cost_usd': float(Decimal(row['line_item_unblended_cost']).quantize(Decimal('0.00001'), rounding=ROUND_HALF_UP)),
                    'net_cost_usd': float(Decimal(row['line_item_net_unblended_cost']).quantize(Decimal('0.00001'), rounding=ROUND_HALF_UP)),
                    'usage_date': usage_date,
                    'event_time': event_time,
                    **fields
                }
            }

            line = json.dumps(event_body)
            line_size = len(line.encode())

            # Flush logs batch if limits reached
            if len(batch) >= MAX_BATCH_COUNT or current_size + line_size > MAX_BATCH_SIZE_BYTES:
                send_to_splunk_batch(batch)
                batch = []
                current_size = 0

            batch.append(line)
            current_size += line_size

            dimensions = {
                'usage_date': usage_date,
                'service': row['line_item_product_code'],
                'resource_id': row['line_item_resource_id'],
                'aws_application': row['user_aws_application'],
                **fields
            }

            # Collect metrics for batch sending
            metrics_batch.append({
                'metric': 'forge.per_resource.cost_usd',
                'value': event_body['event']['cost_usd'],
                'timestamp': now_ts,
                'dimensions': dimensions
            })
            metrics_batch.append({
                'metric': 'forge.per_resource.net_cost_usd',
                'value': event_body['event']['net_cost_usd'],
                'timestamp': now_ts,
                'dimensions': dimensions
            })

            # Flush metrics batch if big enough
            if len(metrics_batch) >= METRICS_BATCH_SIZE:
                send_metric_to_o11y_batch(metrics_batch)
                metrics_batch = []

        # Flush remaining batches
        if batch:
            send_to_splunk_batch(batch)
        if metrics_batch:
            send_metric_to_o11y_batch(metrics_batch)

    print('[INFO] Lambda execution finished.')
    return {'statusCode': 200}
