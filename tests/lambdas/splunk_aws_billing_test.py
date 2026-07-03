"""Splunk AWS billing Lambda pure helper tests.

The billing handlers import pandas/parquet tooling that is not part of the
current unit-test dependency set. These tests keep to deterministic helper and
event-body behavior with a tiny pandas shim, avoiding parquet fixture churn.
"""

from __future__ import annotations

import datetime as dt
import importlib.util
import sys
import types
from pathlib import Path

from conftest import requires_aws

pytestmark = requires_aws

BILLING_DIR = Path(__file__).resolve().parents[2].joinpath(
    'modules',
    'integrations',
    'splunk_aws_billing',
    'lambda',
)


def _fake_pandas():
    pandas = types.ModuleType('pandas')
    pandas.to_datetime = lambda value: dt.datetime.fromisoformat(str(value))
    return pandas


def _load_billing_module(monkeypatch, module_name):
    if str(BILLING_DIR) not in sys.path:
        sys.path.insert(0, str(BILLING_DIR))
    monkeypatch.setitem(sys.modules, 'pandas', _fake_pandas())

    if module_name != 'common' and 'common' not in sys.modules:
        _load_billing_module(monkeypatch, 'common')

    monkeypatch.delitem(sys.modules, module_name, raising=False)
    spec = importlib.util.spec_from_file_location(
        module_name,
        BILLING_DIR / f'{module_name}.py',
    )
    if spec is None or spec.loader is None:
        raise ImportError(f'Cannot load billing module {module_name}')
    module = importlib.util.module_from_spec(spec)
    monkeypatch.setitem(sys.modules, module_name, module)
    spec.loader.exec_module(module)
    return module


class _GroupedRows:
    def __init__(self, rows):
        self.rows = rows

    def iterrows(self):
        return enumerate(self.rows)


def test_parse_tags_accepts_supported_shapes(monkeypatch, aws):
    common = _load_billing_module(monkeypatch, 'common')

    assert common.parse_tags({'a': 'b'}) == {'a': 'b'}
    assert common.parse_tags([['a', 'b']]) == {'a': 'b'}
    assert common.parse_tags('{"a":"b"}') == {'a': 'b'}
    assert common.parse_tags('[["a","b"]]') == {'a': 'b'}


def test_parse_tags_rejects_malformed_values(monkeypatch, aws):
    common = _load_billing_module(monkeypatch, 'common')

    assert common.parse_tags('[not-json') == {}
    assert common.parse_tags([['a']]) == {}
    assert common.parse_tags(None) == {}


def test_extract_arn_parts_for_resource_group_application(monkeypatch, aws):
    common = _load_billing_module(monkeypatch, 'common')

    parts = common.extract_arn_parts(
        'arn:aws:resource-groups:us-west-2:123456789012:'
        'group/acgw-usw2-dev/resources'
    )

    assert parts == {
        'aws_region': 'us-west-2',
        'account_id': '123456789012',
        'forgecicd_tenant': 'acgw',
        'forgecicd_region_alias': 'usw2',
        'forgecicd_vpc_alias': 'dev',
    }
    assert common.extract_arn_parts('not-an-arn')['aws_region'] == 'unknown'


def test_per_service_event_body_rounds_costs(monkeypatch, aws):
    monkeypatch.setenv('SPLUNK_INDEX', 'forge-billing')
    mod = _load_billing_module(monkeypatch, 'handler_per_service')
    row = {
        'usage_date': '2026-07-03',
        'line_item_product_code': 'AmazonEC2',
        'user_aws_application': (
            'arn:aws:resource-groups:us-west-2:123456789012:'
            'group/acgw-usw2-dev/resources'
        ),
        'line_item_unblended_cost': '1.234565',
        'line_item_net_unblended_cost': '2.000004',
    }

    event = mod.create_event_body(row, {'forgecicd_tenant': 'acgw'})

    assert event['source'] == 'aws-cur-per-service'
    assert event['index'] == 'forge-billing'
    assert event['event']['service'] == 'AmazonEC2'
    assert event['event']['cost_usd'] == 1.23457
    assert event['event']['net_cost_usd'] == 2.0
    assert event['event']['usage_year'] == '2026'
    assert event['event']['usage_month'] == '07'
    assert event['event']['forgecicd_tenant'] == 'acgw'


def test_per_resource_event_body_includes_resource_id(monkeypatch, aws):
    mod = _load_billing_module(monkeypatch, 'handler_per_resource_process')
    row = {
        'usage_date': '2026-07-03',
        'line_item_product_code': 'AmazonS3',
        'line_item_resource_id': 'bucket-1',
        'user_aws_application': 'app-arn',
        'line_item_unblended_cost': '0.100004',
        'line_item_net_unblended_cost': '0.100005',
    }

    event = mod.create_event_body(row, {'aws_region': 'us-west-2'})

    assert event['source'] == 'aws-cur-per-resource'
    assert event['event']['resource_id'] == 'bucket-1'
    assert event['event']['cost_usd'] == 0.1
    assert event['event']['net_cost_usd'] == 0.10001
    assert event['event']['aws_region'] == 'us-west-2'


def test_per_service_batches_events_and_o11y_metrics(monkeypatch, aws):
    mod = _load_billing_module(monkeypatch, 'handler_per_service')
    splunk_batches = []
    metric_batches = []
    monkeypatch.setattr(mod.common, 'MAX_BATCH_COUNT', 1)
    monkeypatch.setattr(mod.common, 'METRICS_BATCH_SIZE', 2)
    monkeypatch.setattr(
        mod.common,
        'send_to_splunk_batch',
        lambda batch: splunk_batches.append(list(batch)),
    )
    monkeypatch.setattr(
        mod.common,
        'send_metric_to_o11y_batch',
        lambda batch: metric_batches.append(list(batch)),
    )

    mod.process_grouped_rows(_GroupedRows([
        {
            'usage_date': '2026-07-03',
            'line_item_product_code': 'AmazonEC2',
            'user_aws_application': (
                'arn:aws:resource-groups:us-west-2:123456789012:'
                'group/acgw-usw2-dev/resources'
            ),
            'line_item_unblended_cost': '1.00',
            'line_item_net_unblended_cost': '0.90',
        },
        {
            'usage_date': '2026-07-03',
            'line_item_product_code': 'AmazonS3',
            'user_aws_application': (
                'arn:aws:resource-groups:us-west-2:123456789012:'
                'group/acgw-usw2-dev/resources'
            ),
            'line_item_unblended_cost': '2.00',
            'line_item_net_unblended_cost': '1.80',
        },
    ]))

    assert len(splunk_batches) == 2
    assert len(metric_batches) == 2
    first_event = mod.json.loads(splunk_batches[0][0])['event']
    assert first_event['service'] == 'AmazonEC2'
    assert first_event['forgecicd_tenant'] == 'acgw'
    assert [metric['metric'] for metric in metric_batches[0]] == [
        'forge.per_service.cost_usd',
        'forge.per_service.net_cost_usd',
    ]


def test_per_resource_batches_include_resource_dimensions(monkeypatch, aws):
    mod = _load_billing_module(monkeypatch, 'handler_per_resource_process')
    metric_batches = []
    monkeypatch.setattr(mod.common, 'MAX_BATCH_COUNT', 10)
    monkeypatch.setattr(mod.common, 'METRICS_BATCH_SIZE', 2)
    monkeypatch.setattr(mod.common, 'send_to_splunk_batch',
                        lambda _batch: None)
    monkeypatch.setattr(
        mod.common,
        'send_metric_to_o11y_batch',
        lambda batch: metric_batches.append(list(batch)),
    )

    mod.process_grouped_rows(_GroupedRows([
        {
            'usage_date': '2026-07-03',
            'line_item_product_code': 'AmazonS3',
            'line_item_resource_id': 'bucket-1',
            'user_aws_application': (
                'arn:aws:resource-groups:us-west-2:123456789012:'
                'group/acgw-usw2-dev/resources'
            ),
            'line_item_unblended_cost': '0.10',
            'line_item_net_unblended_cost': '0.08',
        },
    ]))

    assert len(metric_batches) == 1
    assert metric_batches[0][0]['metric'] == 'forge.per_resource.cost_usd'
    assert metric_batches[0][0]['dimensions']['resource_id'] == 'bucket-1'
    assert metric_batches[0][0]['dimensions']['forgecicd_tenant'] == 'acgw'
