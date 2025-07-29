# -*- coding: utf-8 -*-
import calendar
import io
import json
from decimal import ROUND_HALF_UP, Decimal
from urllib.parse import unquote

import boto3
import common
import pandas as pd

s3 = boto3.client('s3')


def create_event_body(row, fields):
    usage_date = str(row['usage_date'])
    event_time = calendar.timegm(pd.to_datetime(usage_date).timetuple())

    return {
        'source': 'aws-cur-per-service',
        'sourcetype': 'forgecicd:aws:billing:cur',
        'index': common.SPLUNK_INDEX,
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


def send_batches(batch, metrics_batch):
    if batch:
        common.send_to_splunk_batch(batch)
    if metrics_batch:
        common.send_metric_to_o11y_batch(metrics_batch)


def process_grouped_rows(grouped):
    batch = []
    current_size = 0
    metrics_batch = []

    for _, row in grouped.iterrows():
        fields = common.extract_arn_parts(row['user_aws_application'])
        event_body = create_event_body(row, fields)
        line = json.dumps(event_body)
        line_size = len(line.encode())

        # Flush logs batch if limits reached
        if len(batch) >= common.MAX_BATCH_COUNT or current_size + line_size > common.MAX_BATCH_SIZE_BYTES:
            common.send_to_splunk_batch(batch)
            batch = []
            current_size = 0

        batch.append(line)
        current_size += line_size

        # Prepare metrics
        dimensions = {
            'usage_date': str(row['usage_date']),
            'service': row['line_item_product_code'],
            'aws_application': row['user_aws_application'],
            **fields
        }
        metrics_batch.append({
            'metric': 'forge.per_service.cost_usd',
            'value': event_body['event']['cost_usd'],
            'dimensions': dimensions
        })
        metrics_batch.append({
            'metric': 'forge.per_service.net_cost_usd',
            'value': event_body['event']['net_cost_usd'],
            'dimensions': dimensions
        })

        # Flush metrics batch if big enough
        if len(metrics_batch) >= common.METRICS_BATCH_SIZE:
            common.send_metric_to_o11y_batch(metrics_batch)
            metrics_batch = []

    send_batches(batch, metrics_batch)


def lambda_handler(event, context):
    print(f'[INFO] Lambda triggered with event: {json.dumps(event)}')

    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = unquote(record['s3']['object']['key'])
        print(f'[INFO] Processing file from bucket: {bucket}, key: {key}')

        obj = s3.get_object(Bucket=bucket, Key=key)
        df = pd.read_parquet(io.BytesIO(obj['Body'].read()))

        df = common.preprocess_df(df)

        grouped = df.groupby(
            ['usage_date', 'line_item_product_code', 'user_aws_application'],
            as_index=False
        ).agg({
            'line_item_unblended_cost': 'sum',
            'line_item_net_unblended_cost': 'sum'
        })

        print(f'[INFO] Grouped {len(grouped)} records for Splunk')

        process_grouped_rows(grouped)

    print('[INFO] Lambda execution finished.')
    return {'statusCode': 200}
