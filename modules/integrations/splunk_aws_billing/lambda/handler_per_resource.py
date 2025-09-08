import io
import json
import logging
from urllib.parse import unquote

import boto3
import common
import pandas as pd

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

s3 = boto3.client('s3')


def lambda_handler(event, context):
    logger.info('Lambda triggered with event: %s', json.dumps(event))

    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = unquote(record['s3']['object']['key'])
        logger.info('Processing file from bucket: %s, key: %s', bucket, key)

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

            logger.info('Uploaded %s (%d rows)', s3_key, len(daily_df))

    return {'statusCode': 200}
