# -*- coding: utf-8 -*-
import io
import json
from urllib.parse import unquote

import boto3
import pandas as pd

s3 = boto3.client('s3')


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


def lambda_handler(event, context):
    print(f'[INFO] Lambda triggered with event: {json.dumps(event)}')
    total_days = 0

    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = unquote(record['s3']['object']['key'])

        print(f'[INFO] Processing file from bucket: {bucket}, key: {key}')
        obj = s3.get_object(Bucket=bucket, Key=key)
        df = pd.read_parquet(io.BytesIO(obj['Body'].read()))

        # Normalize and prepare data
        df['line_item_usage_start_date'] = pd.to_datetime(
            df['line_item_usage_start_date'])
        df['usage_date'] = df['line_item_usage_start_date'].dt.date

        # Clean tags and extract 'user_aws_application'
        df['resource_tags'] = df['resource_tags'].apply(parse_tags)
        df['user_aws_application'] = df['resource_tags'].apply(
            lambda tags: tags.get('user_aws_application', 'unknown')
        )

        # Filter out rows without the tag
        df = df[df['user_aws_application'] != 'unknown']

        # Group and write per-day files
        for date, daily_df in df.groupby('usage_date'):
            year, month, day = date.year, f'{date.month:02}', f'{date.day:02}'
            tmp_file = f'/tmp/cur_{date}.parquet'
            daily_df.to_parquet(tmp_file, index=False)

            s3_key = f'tmp/cur-per-resource/year={year}/month={month}/day={day}/data.parquet'
            s3.upload_file(tmp_file, bucket, s3_key)
            print(f'✅ Uploaded {s3_key} ({len(daily_df)} rows)')
            total_days += 1

    return {'statusCode': 200, 'days_processed': total_days}
