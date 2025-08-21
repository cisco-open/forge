import gzip
import json
import os
import re

import boto3
import pandas as pd
import requests

SPLUNK_HEC_URL = os.environ.get('SPLUNK_HEC_URL', '')
SPLUNK_HEC_TOKEN = os.environ.get('SPLUNK_HEC_TOKEN', '')
SPLUNK_INDEX = os.environ.get('SPLUNK_INDEX', '')
SPLUNK_METRICS_TOKEN = os.environ.get('SPLUNK_METRICS_TOKEN', '')
SPLUNK_METRICS_URL = os.environ.get('SPLUNK_METRICS_URL', '')

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


def preprocess_df(df):
    print(f'[INFO] Raw DataFrame shape: {df.shape}')

    df['line_item_usage_start_date'] = pd.to_datetime(
        df['line_item_usage_start_date'])
    df['usage_date'] = df['line_item_usage_start_date'].dt.date

    df['resource_tags'] = df['resource_tags'].apply(parse_tags)
    df['user_aws_application'] = df['resource_tags'].apply(
        lambda tags: tags.get('user_aws_application', 'unknown'))
    df = df[df['user_aws_application'] != 'unknown']

    print(f'[INFO] Preprocessed DataFrame shape: {df.shape}')
    return df
