"""Splunk Cloud and Splunk Observability HTTP delivery helpers."""

from __future__ import annotations

import gzip
import json
import logging
import os
import time
from typing import Any

LOG = logging.getLogger()

SPLUNK_HEC_TOKEN = os.environ.get('SPLUNK_HEC_TOKEN', '')
SPLUNK_HEC_URL = os.environ.get('SPLUNK_HEC_URL', '')
SPLUNK_INDEX = os.environ.get('SPLUNK_INDEX', '')
SPLUNK_METRICS_TOKEN = os.environ.get('SPLUNK_METRICS_TOKEN', '')
SPLUNK_METRICS_URL = os.environ.get('SPLUNK_METRICS_URL', '')
SPLUNK_HTTP_TIMEOUT_SECONDS = int(
    os.environ.get('SPLUNK_HTTP_TIMEOUT_SECONDS', '10')
)


def _post_with_retries(
    url: str,
    *,
    headers: dict[str, str],
    data: bytes | None = None,
    json_payload: dict[str, Any] | None = None,
) -> None:
    import requests

    last_error: Exception | None = None
    for attempt in range(3):
        try:
            response = requests.post(
                url,
                headers=headers,
                data=data,
                json=json_payload,
                timeout=SPLUNK_HTTP_TIMEOUT_SECONDS,
            )
        except Exception as error:
            last_error = error
        else:
            if 200 <= response.status_code < 300:
                return
            last_error = RuntimeError(
                f"Splunk HTTP request failed with status "
                f"{response.status_code}"
            )
            if response.status_code != 429 and response.status_code < 500:
                break
        if attempt < 2:
            time.sleep(2**attempt)

    raise RuntimeError(
        'Splunk HTTP delivery failed after bounded retries'
    ) from last_error


def send_to_splunk_batch(events: list[dict[str, Any]]) -> int:
    """Send newline-delimited, gzip-compressed events to Splunk Cloud HEC."""
    if not events:
        return 0
    if not SPLUNK_HEC_URL or not SPLUNK_HEC_TOKEN or not SPLUNK_INDEX:
        raise ValueError('Splunk Cloud HEC configuration is incomplete')

    payload = '\n'.join(
        json.dumps(event, separators=(',', ':'), sort_keys=True)
        for event in events
    )
    _post_with_retries(
        SPLUNK_HEC_URL,
        headers={
            'Authorization': f"Splunk {SPLUNK_HEC_TOKEN}",
            'Content-Type': 'application/json',
            'Content-Encoding': 'gzip',
        },
        data=gzip.compress(payload.encode('utf-8')),
    )
    return len(events)


def send_metric_to_o11y_batch(metrics: list[dict[str, Any]]) -> int:
    """Send gauge datapoints to the Splunk Observability ingest endpoint."""
    if not metrics:
        return 0
    if not SPLUNK_METRICS_URL or not SPLUNK_METRICS_TOKEN:
        raise ValueError(
            'Splunk Observability ingest configuration is incomplete'
        )

    _post_with_retries(
        SPLUNK_METRICS_URL,
        headers={
            'X-SF-TOKEN': SPLUNK_METRICS_TOKEN,
            'Content-Type': 'application/json',
        },
        json_payload={'gauge': metrics},
    )
    return len(metrics)
