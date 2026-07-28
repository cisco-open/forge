import gzip
import json
import logging
import os
import random
import re
import time

import boto3
import pandas as pd
import requests
from botocore.exceptions import BotoCoreError, ClientError

SPLUNK_HEC_URL = os.environ.get('SPLUNK_HEC_URL', '')
SPLUNK_HEC_TOKEN = os.environ.get('SPLUNK_HEC_TOKEN', '')
SPLUNK_INDEX = os.environ.get('SPLUNK_INDEX', '')
SPLUNK_METRICS_TOKEN = os.environ.get('SPLUNK_METRICS_TOKEN', '')
SPLUNK_METRICS_URL = os.environ.get('SPLUNK_METRICS_URL', '')

MAX_BATCH_SIZE_BYTES = 950_000
MAX_BATCH_COUNT = 500
METRICS_BATCH_SIZE = 500
DELIVERY_MAX_ATTEMPTS = 3
DELIVERY_MAX_RETRY_DELAY_SECONDS = 10
DELIVERY_RETRYABLE_STATUS_CODES = {429, 500, 502, 503, 504}

LOG = logging.getLogger()
level_str = os.environ.get('LOG_LEVEL', 'INFO').upper()
LOG.setLevel(getattr(logging, level_str, logging.INFO))

s3 = boto3.client('s3')
cloudwatch = boto3.client('cloudwatch')


def _retry_delay_seconds(response, attempt):
    retry_after = (
        response.headers.get('Retry-After') if response is not None else None
    )
    if retry_after is not None:
        try:
            return min(
                max(float(retry_after), 0),
                DELIVERY_MAX_RETRY_DELAY_SECONDS,
            )
        except (TypeError, ValueError):
            pass

    maximum_delay = min(
        2 ** (attempt - 1),
        DELIVERY_MAX_RETRY_DELAY_SECONDS,
    )
    return random.uniform(0, maximum_delay)


def _record_delivery_failure(destination, batch_size, error):
    """Emit a structured error and an explicit CloudWatch failure metric."""
    LOG.error(json.dumps({
        'event': 'billing_delivery_failed',
        'Destination': destination,
        'BatchSize': batch_size,
        'Error': str(error),
    }))
    try:
        cloudwatch.put_metric_data(
            Namespace='Forge/Billing',
            MetricData=[{
                'MetricName': 'DeliveryFailures',
                'Dimensions': [{
                    'Name': 'Destination',
                    'Value': destination,
                }],
                'Value': 1,
                'Unit': 'Count',
            }],
        )
    except (BotoCoreError, ClientError) as metric_error:
        LOG.error(
            'Failed to publish billing delivery failure metric: %s',
            metric_error,
        )


def _post_with_retry(destination, batch_size, url, **request_kwargs):
    for attempt in range(1, DELIVERY_MAX_ATTEMPTS + 1):
        try:
            response = requests.post(url, **request_kwargs)
        except (requests.ConnectionError, requests.Timeout) as error:
            if attempt == DELIVERY_MAX_ATTEMPTS:
                _record_delivery_failure(destination, batch_size, error)
                return None

            delay = _retry_delay_seconds(None, attempt)
            LOG.warning(
                '%s delivery failed transiently on attempt %s/%s: %s. '
                'Retrying in %s seconds.',
                destination,
                attempt,
                DELIVERY_MAX_ATTEMPTS,
                error,
                delay,
            )
            time.sleep(delay)
            continue
        except requests.RequestException as error:
            _record_delivery_failure(destination, batch_size, error)
            return None

        retryable = response.status_code in DELIVERY_RETRYABLE_STATUS_CODES
        if retryable and attempt < DELIVERY_MAX_ATTEMPTS:
            delay = _retry_delay_seconds(response, attempt)
            LOG.warning(
                '%s delivery returned retryable status %s on attempt %s/%s. '
                'Retrying in %s seconds.',
                destination,
                response.status_code,
                attempt,
                DELIVERY_MAX_ATTEMPTS,
                delay,
            )
            time.sleep(delay)
            continue

        try:
            response.raise_for_status()
        except requests.RequestException as error:
            _record_delivery_failure(destination, batch_size, error)
            return None
        return response

    raise RuntimeError('Billing delivery retry loop exhausted unexpectedly')


def send_to_splunk_batch(events):
    if not events:
        return True

    payload = '\n'.join(events)
    headers = {
        'Authorization': f'Splunk {SPLUNK_HEC_TOKEN}',
        'Content-Type': 'application/json',
        'Content-Encoding': 'gzip'
    }
    compressed_payload = gzip.compress(payload.encode())

    resp = _post_with_retry(
        'splunk_hec',
        len(events),
        SPLUNK_HEC_URL,
        headers=headers,
        data=compressed_payload,
        timeout=10,
    )
    if resp is None:
        return False

    LOG.info('[Splunk Batch] Sent %d events | Status: %s',
             len(events), resp.status_code)
    return True


def send_metric_to_o11y_batch(metrics):
    if not metrics:
        return True

    payload = {
        'gauge': metrics
    }
    headers = {
        'X-SF-TOKEN': SPLUNK_METRICS_TOKEN,
        'Content-Type': 'application/json'
    }
    resp = _post_with_retry(
        'splunk_o11y',
        len(metrics),
        SPLUNK_METRICS_URL,
        headers=headers,
        json=payload,
        timeout=10,
    )
    if resp is None:
        return False

    LOG.info('[O11y Batch] Sent %d metrics | Status: %s',
             len(metrics), resp.status_code)
    return True


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
            return parse_tags(json.loads(val))
        except json.JSONDecodeError:
            return {}
    return {}


def preprocess_df(df):
    LOG.info('Raw DataFrame shape: %s', df.shape)

    df['line_item_usage_start_date'] = pd.to_datetime(
        df['line_item_usage_start_date'])
    df['usage_date'] = df['line_item_usage_start_date'].dt.date

    df['resource_tags'] = df['resource_tags'].apply(parse_tags)
    df['user_aws_application'] = df['resource_tags'].apply(
        lambda tags: tags.get('user_aws_application', 'unknown'))
    df = df[df['user_aws_application'] != 'unknown']

    LOG.info('Preprocessed DataFrame shape: %s', df.shape)
    return df
