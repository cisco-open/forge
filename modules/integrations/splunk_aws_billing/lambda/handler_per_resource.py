import io
import json
from urllib.parse import unquote

import boto3
import common
import pandas as pd

s3 = boto3.client('s3')


def lambda_handler(event, context):
    print(f'[INFO] Lambda triggered with event: {json.dumps(event)}')

    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = unquote(record['s3']['object']['key'])
        print(f'[INFO] Processing file from bucket: {bucket}, key: {key}')

        obj = s3.get_object(Bucket=bucket, Key=key)
        df = pd.read_parquet(io.BytesIO(obj['Body'].read()))

        df = common.preprocess_df(df)

        for date, daily_df in df.groupby('usage_date'):
            year = date.year
            month = f'{date.month:02}'
            day = f'{date.day:02}'

            tmp_path = f'/tmp/cur_{year}{month}{day}.parquet'
            daily_df.to_parquet(tmp_path, index=False)

            s3_key = f'tmp/cur-per-resource/{key}/day={day}/data.parquet'
            s3.upload_file(tmp_path, bucket, s3_key)

            print(f'Uploaded {s3_key} ({len(daily_df)} rows)')

    return {'statusCode': 200}
