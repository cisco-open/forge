import calendar
import io
import json
import logging
import os
from decimal import ROUND_HALF_UP, Decimal
from urllib.parse import unquote

import boto3
import common
import pandas as pd

LOG = logging.getLogger()
level_str = os.environ.get('LOG_LEVEL', 'INFO').upper()
LOG.setLevel(getattr(logging, level_str, logging.INFO))

s3 = boto3.client('s3')


def create_event_body(row, fields):
    usage_date = str(row['usage_date'])
    dt = pd.to_datetime(usage_date)

    event_time = calendar.timegm(dt.timetuple())

    usage_year = str(dt.year)
    usage_month = str(dt.month).zfill(2)

    return {
        'source': 'aws-cur-per-resource',
        'sourcetype': 'forgecicd:aws:billing:cur',
        'index': common.SPLUNK_INDEX,
        'event': {
            'service': row['line_item_product_code'],
            'resource_id': row['line_item_resource_id'],
            'aws_application': row['user_aws_application'],
            'cost_usd': float(Decimal(row['line_item_unblended_cost']).quantize(Decimal('0.00001'), rounding=ROUND_HALF_UP)),
            'net_cost_usd': float(Decimal(row['line_item_net_unblended_cost']).quantize(Decimal('0.00001'), rounding=ROUND_HALF_UP)),
            'usage_date': usage_date,
            'usage_year': usage_year,
            'usage_month': usage_month,
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

        if len(batch) >= common.MAX_BATCH_COUNT or current_size + line_size > common.MAX_BATCH_SIZE_BYTES:
            common.send_to_splunk_batch(batch)
            batch = []
            current_size = 0

        batch.append(line)
        current_size += line_size

        dt = pd.to_datetime(row['usage_date'])
        usage_year = str(dt.year)
        usage_month = str(dt.month).zfill(2)

        dimensions = {
            'usage_date': str(row['usage_date']),
            'usage_year': usage_year,
            'usage_month': usage_month,
            'service': row['line_item_product_code'],
            'resource_id': row['line_item_resource_id'],
            'aws_application': row['user_aws_application'],
            **fields
        }
        metrics_batch.append({
            'metric': 'forge.per_resource.cost_usd',
            'value': event_body['event']['cost_usd'],
            'dimensions': dimensions
        })
        metrics_batch.append({
            'metric': 'forge.per_resource.net_cost_usd',
            'value': event_body['event']['net_cost_usd'],
            'dimensions': dimensions
        })

        if len(metrics_batch) >= common.METRICS_BATCH_SIZE:
            common.send_metric_to_o11y_batch(metrics_batch)
            metrics_batch = []

    send_batches(batch, metrics_batch)


def lambda_handler(event, context):
    LOG.info('Lambda triggered with event: %s', json.dumps(event))

    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = unquote(record['s3']['object']['key'])
        LOG.info('Processing file from bucket: %s, key: %s', bucket, key)

        obj = s3.get_object(Bucket=bucket, Key=key)
        df = pd.read_parquet(io.BytesIO(obj['Body'].read()))

        grouped = df.groupby(
            ['usage_date', 'line_item_resource_id',
             'line_item_product_code', 'user_aws_application'],
            as_index=False
        ).agg({
            'line_item_unblended_cost': 'sum',
            'line_item_net_unblended_cost': 'sum'
        })

        LOG.info('Grouped %d records for Splunk', len(grouped))

        process_grouped_rows(grouped)

    LOG.info('Lambda execution finished.')
    return {'statusCode': 200}
