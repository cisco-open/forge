"""Splunk delivery tests for the dependency-monitor Lambda."""

from __future__ import annotations

import gzip
import importlib.util
import json
import sys
from pathlib import Path
from types import SimpleNamespace

import pytest
from conftest import requires_aws

pytestmark = requires_aws

LAMBDA_DIR = Path(__file__).resolve().parents[2].joinpath(
    'modules',
    'integrations',
    'splunk_dependency_monitor',
    'lambda',
)


def _load_common(monkeypatch, **environment):
    defaults = {
        'SPLUNK_HEC_TOKEN': 'hec-test-token',
        'SPLUNK_HEC_URL': 'https://splunk.example/services/collector',
        'SPLUNK_HTTP_TIMEOUT_SECONDS': '9',
        'SPLUNK_INDEX': 'forge-test-index',
        'SPLUNK_METRICS_TOKEN': 'metrics-test-token',
        'SPLUNK_METRICS_URL': 'https://o11y.example/v2/datapoint',
    }
    defaults.update(environment)
    for name, value in defaults.items():
        monkeypatch.setenv(name, value)
    spec = importlib.util.spec_from_file_location(
        'splunk_dependency_monitor_delivery_under_test',
        LAMBDA_DIR / 'common.py',
    )
    if spec is None or spec.loader is None:
        raise ImportError('Cannot load dependency-monitor common module')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_empty_batches_do_not_require_configuration(monkeypatch, aws):
    common = _load_common(
        monkeypatch,
        SPLUNK_HEC_TOKEN='',
        SPLUNK_HEC_URL='',
        SPLUNK_INDEX='',
        SPLUNK_METRICS_TOKEN='',
        SPLUNK_METRICS_URL='',
    )

    assert common.send_to_splunk_batch([]) == 0
    assert common.send_metric_to_o11y_batch([]) == 0


@pytest.mark.parametrize(
    ('function_name', 'environment'),
    [
        ('send_to_splunk_batch', {'SPLUNK_HEC_TOKEN': ''}),
        ('send_to_splunk_batch', {'SPLUNK_HEC_URL': ''}),
        ('send_to_splunk_batch', {'SPLUNK_INDEX': ''}),
        ('send_metric_to_o11y_batch', {'SPLUNK_METRICS_TOKEN': ''}),
        ('send_metric_to_o11y_batch', {'SPLUNK_METRICS_URL': ''}),
    ],
)
def test_non_empty_batches_reject_incomplete_configuration(
    monkeypatch, aws, function_name, environment
):
    common = _load_common(monkeypatch, **environment)

    with pytest.raises(ValueError):
        getattr(common, function_name)([{'value': 1}])


def test_hec_batch_is_newline_delimited_gzip(monkeypatch, aws):
    common = _load_common(monkeypatch)
    calls = []

    def post(url, **kwargs):
        calls.append((url, kwargs))
        return SimpleNamespace(status_code=200)

    monkeypatch.setitem(sys.modules, 'requests', SimpleNamespace(post=post))
    events = [
        {'index': 'forge-test-index', 'event': {'tenant': 'a'}},
        {'index': 'forge-test-index', 'event': {'tenant': 'b'}},
    ]

    assert common.send_to_splunk_batch(events) == 2
    assert calls[0][0] == 'https://splunk.example/services/collector'
    assert calls[0][1]['timeout'] == 9
    assert calls[0][1]['headers'] == {
        'Authorization': 'Splunk hec-test-token',
        'Content-Type': 'application/json',
        'Content-Encoding': 'gzip',
    }
    decoded = gzip.decompress(calls[0][1]['data']).decode()
    assert [json.loads(line) for line in decoded.splitlines()] == events


def test_o11y_batch_uses_gauge_payload(monkeypatch, aws):
    common = _load_common(monkeypatch)
    calls = []

    def post(url, **kwargs):
        calls.append((url, kwargs))
        return SimpleNamespace(status_code=202)

    monkeypatch.setitem(sys.modules, 'requests', SimpleNamespace(post=post))
    metrics = [{'metric': 'forge.test', 'value': 1}]

    assert common.send_metric_to_o11y_batch(metrics) == 1
    assert calls == [
        (
            'https://o11y.example/v2/datapoint',
            {
                'headers': {
                    'X-SF-TOKEN': 'metrics-test-token',
                    'Content-Type': 'application/json',
                },
                'data': None,
                'json': {'gauge': metrics},
                'timeout': 9,
            },
        )
    ]


@pytest.mark.parametrize('first_status', [429, 500, 503])
def test_retryable_http_status_is_retried(
    monkeypatch, aws, first_status
):
    common = _load_common(monkeypatch)
    statuses = iter([first_status, 200])
    sleeps = []
    calls = []

    def post(*_args, **_kwargs):
        calls.append(True)
        return SimpleNamespace(status_code=next(statuses))

    monkeypatch.setitem(sys.modules, 'requests', SimpleNamespace(post=post))
    monkeypatch.setattr(common.time, 'sleep', sleeps.append)

    common._post_with_retries('https://splunk.example', headers={})

    assert len(calls) == 2
    assert sleeps == [1]


def test_client_error_is_not_retried(monkeypatch, aws):
    common = _load_common(monkeypatch)
    sleeps = []
    calls = []

    def post(*_args, **_kwargs):
        calls.append(True)
        return SimpleNamespace(
            status_code=403,
            json=lambda: {'code': 4, 'text': 'Invalid token'},
        )

    monkeypatch.setitem(sys.modules, 'requests', SimpleNamespace(post=post))
    monkeypatch.setattr(common.time, 'sleep', sleeps.append)

    with pytest.raises(
        RuntimeError, match='bounded retries'
    ) as raised:
        common._post_with_retries('https://splunk.example', headers={})

    assert len(calls) == 1
    assert sleeps == []
    assert isinstance(raised.value.__cause__, RuntimeError)
    assert 'status 403' in str(raised.value.__cause__)
    assert common.delivery_error_context(raised.value) == {
        'cause_type': 'RuntimeError',
        'http_status': '403',
        'response_code': '4',
        'response_text': 'Invalid token',
    }


def test_network_failure_uses_bounded_exponential_retries(
    monkeypatch, aws
):
    common = _load_common(monkeypatch)
    sleeps = []
    calls = []

    def post(*_args, **_kwargs):
        calls.append(True)
        raise OSError('network unavailable')

    monkeypatch.setitem(sys.modules, 'requests', SimpleNamespace(post=post))
    monkeypatch.setattr(common.time, 'sleep', sleeps.append)

    with pytest.raises(RuntimeError, match='bounded retries') as raised:
        common._post_with_retries('https://splunk.example', headers={})

    assert len(calls) == 3
    assert sleeps == [1, 2]
    assert isinstance(raised.value.__cause__, OSError)
