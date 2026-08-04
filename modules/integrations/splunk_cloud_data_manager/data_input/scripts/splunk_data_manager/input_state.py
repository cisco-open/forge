"""Validate Splunk input documents and track S3 provisioning state."""

from __future__ import annotations

import json
import re
import time
from collections.abc import Callable
from urllib.parse import urlsplit

from .runtime import JsonObject, SplunkHttpError, SplunkIntegrationError

S3_DATASETS = frozenset(
    {
        's3-custom-logs',
        'ct-logs',
        's3-access-logs',
        'elb-access-logs',
        'cf-access-logs',
    }
)

S3_STATUS_HOST = re.compile(
    r'^sqs\.(?P<region>[^.]+)\.amazonaws\.com(?:\.cn)?$'
)


def validate_input_document(document: object) -> bool:
    """Return whether a request or response has a datasetInfo object."""
    if not isinstance(document, dict):
        return False
    details = document.get('details')
    return isinstance(details, dict) and isinstance(
        details.get('datasetInfo'),
        dict,
    )


def input_uses_s3(document: JsonObject) -> bool:
    """Return whether the input contains one supported pull-based S3 dataset."""
    return _s3_dataset_name(document) is not None


def _s3_dataset_name(document: JsonObject) -> str | None:
    """Return the single supported S3 dataset name in an input, if present."""
    if not validate_input_document(document):
        return None
    datasets = [
        dataset
        for dataset in document['details']['datasetInfo']
        if dataset in S3_DATASETS
    ]
    if len(datasets) > 1:
        raise SplunkIntegrationError(
            'Splunk input contains more than one supported S3 dataset'
        )
    return datasets[0] if datasets else None


def s3_input_matches_request(
    actual: JsonObject,
    requested: JsonObject,
) -> bool:
    """Compare only request-owned fields in an S3 input response."""
    if not validate_input_document(actual):
        return False
    if not validate_input_document(requested):
        return False

    for key in ('name', 'type', 'destination', 'mode'):
        if actual.get(key) != requested.get(key):
            return False

    detail_keys = (
        'type',
        'iamRegion',
        'datasetInfo',
        'dataAccounts',
        's3BucketPatterns',
        'kmsKeyArns',
    )
    actual_details = actual['details']
    requested_details = requested['details']
    return {
        key: actual_details.get(key)
        for key in detail_keys
    } == {
        key: requested_details.get(key)
        for key in detail_keys
    }


def _s3_status_key(queue_url: str, input_id: str) -> str:
    parsed = urlsplit(queue_url)
    host_match = S3_STATUS_HOST.fullmatch(parsed.hostname or '')
    path_parts = parsed.path.strip('/').split('/')
    valid_host = parsed.scheme == 'https' and host_match is not None
    valid_path = len(path_parts) == 2
    if valid_path:
        valid_path = path_parts[0].isdigit() and bool(path_parts[1])
    if not valid_host or not valid_path:
        raise SplunkIntegrationError(
            f'Invalid SQS queue URL in Splunk input: {queue_url}'
        )
    return (
        f'scc_{host_match.group("region")}_{path_parts[1]}_{input_id}'
    )


def s3_input_state(document: JsonObject) -> str:
    """Classify S3 provisioning as pending, ready, or failed."""
    dataset_name = _s3_dataset_name(document)
    if dataset_name is None:
        raise SplunkIntegrationError(
            'Cannot classify a non-S3 Data Manager input'
        )

    input_id = document.get('id') or document.get('_key') or ''
    details = document['details']
    s3_dataset = details['datasetInfo'][dataset_name]
    if not isinstance(s3_dataset, dict):
        raise SplunkIntegrationError(
            'Splunk returned invalid S3 dataset metadata'
        )
    queue_entries = s3_dataset.get('sqsUrls', [])
    if not isinstance(queue_entries, list):
        raise SplunkIntegrationError(
            'Splunk returned invalid S3 queue status metadata'
        )

    queue_urls = [
        entry.get('sqsUrl', '')
        for entry in queue_entries
        if isinstance(entry, dict)
    ]
    if len(queue_urls) != len(queue_entries):
        raise SplunkIntegrationError(
            'Splunk returned invalid S3 queue status metadata'
        )

    expected_keys = [
        _s3_status_key(queue_url, str(input_id))
        for queue_url in queue_urls
    ]
    status_map = document.get('dataSourcesStatus', {})
    if not isinstance(status_map, dict):
        raise SplunkIntegrationError(
            'Splunk returned invalid dataSourcesStatus metadata'
        )

    states = []
    for key in expected_keys:
        status_entry = status_map.get(key)
        if not isinstance(status_entry, dict):
            states.append('')
            continue
        status = status_entry.get('status')
        state = status.get('state', '') if isinstance(status, dict) else ''
        states.append(state if isinstance(state, str) else '')

    if any(
        'fail' in state.lower() or 'error' in state.lower()
        for state in states
    ):
        return 'failed'
    if any(
        (
            not details.get('stackName'),
            details.get('version') is None,
            not input_id,
            not expected_keys,
            len(expected_keys) != len(queue_entries),
            any(not state for state in states),
        )
    ):
        return 'pending'
    if all(state.endswith('Success') for state in states):
        return 'ready'
    return 'pending'


def wait_for_input(
    fetch: Callable[[], JsonObject],
    *,
    request: JsonObject | None = None,
    expected_version: str | None = None,
    expected_update_time: str | None = None,
    max_attempts: int = 60,
    poll_interval_seconds: int = 5,
    sleep: Callable[[float], None] = time.sleep,
) -> JsonObject:
    """Fetch until the input is current and every S3 queue is ready."""
    for attempt in range(1, max_attempts + 1):
        try:
            document = fetch()
        except SplunkHttpError as error:
            if not error.retryable:
                raise SplunkIntegrationError(
                    'Splunk input fetch failed with a non-retryable '
                    f'HTTP {error.status} response'
                ) from error
            if attempt == max_attempts:
                break
            sleep(poll_interval_seconds)
            continue

        if not validate_input_document(document):
            raise SplunkIntegrationError(
                'Splunk returned an invalid data input response'
            )
        if not input_uses_s3(document):
            return document

        matches_expected_update = request is None or s3_input_matches_request(
            document,
            request,
        )
        if expected_version is not None:
            matches_expected_update = all(
                (
                    matches_expected_update,
                    document['details'].get('version') is not None,
                    str(document['details']['version']) == expected_version,
                )
            )
        if expected_update_time is not None:
            matches_expected_update = all(
                (
                    matches_expected_update,
                    document.get('lastUpdateTime') == expected_update_time,
                )
            )

        state = (
            s3_input_state(document)
            if matches_expected_update
            else 'pending'
        )
        if state == 'ready':
            return document
        if state == 'failed':
            status = json.dumps(
                document.get('dataSourcesStatus', {}),
                separators=(',', ':'),
            )
            raise SplunkIntegrationError(
                f'Splunk S3 data source provisioning failed: {status}'
            )
        if attempt < max_attempts:
            sleep(poll_interval_seconds)

    raise SplunkIntegrationError(
        f'Splunk S3 data source was not ready after {max_attempts} attempts'
    )
