# -*- coding: utf-8 -*-
import calendar
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

s3 = boto3.client('s3')


def send_to_splunk(event):
    headers = {
        'Authorization': f'Splunk {SPLUNK_HEC_TOKEN}',
    }
    try:
        resp = requests.post(SPLUNK_HEC_URL, json=event,
                             headers=headers, timeout=10)
        print(
            f'[Splunk Response] Status: {resp.status_code}, Body: {resp.text}')
        resp.raise_for_status()
    except requests.HTTPError as e:
        print(f'[HTTPError] {e.response.status_code} - {e.response.text}')
    except requests.RequestException as e:
        print(f'[RequestException] Error sending to Splunk: {e}')


def send_metric_to_o11y(metric_name, value, timestamp, dimensions):
    headers = {
        'X-SF-TOKEN': SPLUNK_METRICS_TOKEN,
        'Content-Type': 'application/json'
    }
    payload = {
        'gauge': [{
            'metric': metric_name,
            'value': value,
            'timestamp': timestamp * 1000,
            'dimensions': dimensions
        }]
    }
    try:
        resp = requests.post(SPLUNK_METRICS_URL,
                             headers=headers, json=payload, timeout=5)
        print(
            f'[O11y] Metric {metric_name} sent: {resp.status_code} {resp.text}')
        resp.raise_for_status()
    except requests.RequestException as e:
        print(f'[O11y ERROR] Failed to send metric {metric_name}: {e}')


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
    df['line_item_usage_start_date'] = pd.to_datetime(
        df['line_item_usage_start_date'])
    df['ingest_time'] = pd.Timestamp.now(tz='UTC')

    def parse_tags(val):
        if isinstance(val, list):
            try:
                return dict(val)
            except (TypeError, ValueError):
                return {}
        elif isinstance(val, dict):
            return val
        elif isinstance(val, str):
            try:
                return json.loads(val)
            except json.JSONDecodeError:
                return {}
        return {}

    df['resource_tags'] = df['resource_tags'].apply(parse_tags)
    df['user_aws_application'] = df['resource_tags'].apply(
        lambda tags: tags.get('user_aws_application', 'unknown'))
    df = df[df['user_aws_application'] != 'unknown']
    df['usage_date'] = df['line_item_usage_start_date'].dt.date

    key_cols = [
        'line_item_usage_start_date',
        'line_item_product_code',
        'user_aws_application',
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
            ['usage_date', 'line_item_product_code', 'user_aws_application'],
            as_index=False
        ).agg({
            'line_item_unblended_cost': 'sum',
            'line_item_net_unblended_cost': 'sum'
        })

        now_ts = int(time.time())

        print(f'[INFO] Grouped {len(grouped)} records for Splunk')

        for _, row in grouped.iterrows():
            fields = extract_arn_parts(row['user_aws_application'])
            usage_date = str(row['usage_date'])
            event_time = calendar.timegm(
                pd.to_datetime(usage_date).timetuple())

            event_data = {
                'source': 'aws-cur-per-service',
                'sourcetype': 'forgecicd:aws:billing:cur',
                'index': SPLUNK_INDEX,
                'event': {
                    'service': row['line_item_product_code'],
                    'aws_application': row['user_aws_application'],
                    'cost_usd': float(Decimal(row['line_item_unblended_cost']).quantize(Decimal('0.00001'), rounding=ROUND_HALF_UP)),
                    'net_cost_usd': float(Decimal(row['line_item_net_unblended_cost']).quantize(Decimal('0.00001'), rounding=ROUND_HALF_UP)),
                    'usage_date': usage_date,
                    'event_time': event_time,
                    **fields
                }
            }

            print(f'[DEBUG] Sending to HEC: {json.dumps(event_data)}')
            send_to_splunk(event_data)

            dimensions = {
                'usage_date': usage_date,
                'service': row['line_item_product_code'],
                'aws_application': row['user_aws_application'],
                **fields
            }

            print(f'[DEBUG] Sending to O11y: {json.dumps(dimensions)}')

            send_metric_to_o11y(
                'forge.per_service.cost_usd', event_data['event']['cost_usd'], now_ts, dimensions)
            send_metric_to_o11y(
                'forge.per_service.net_cost_usd', event_data['event']['net_cost_usd'], now_ts, dimensions)

    print('[INFO] Lambda execution finished.')
    return {'statusCode': 200}
