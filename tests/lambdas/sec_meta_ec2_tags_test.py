"""Splunk Data Manager EC2 tag metadata Lambda tests."""

from __future__ import annotations

import json
import urllib.error

import boto3
from conftest import AWS_REGION, requires_aws
from support import load_handler_module

pytestmark = requires_aws


def _create_tags_event(*resource_ids):
    return {
        'account': '123456789012',
        'region': AWS_REGION,
        'detail': {
            'eventName': 'CreateTags',
            'requestParameters': {
                'resourcesSet': {
                    'items': [
                        {'resourceId': resource_id}
                        for resource_id in resource_ids
                    ],
                },
            },
        },
    }


def test_extract_instance_ids_filters_non_ec2_resources(monkeypatch, aws):
    mod = load_handler_module('sec_meta_ec2_tags')

    ids = mod.extract_instance_ids_from_createtags(
        _create_tags_event('i-1234567890abcdef0', 'vol-1', '', None)
    )

    assert ids == ['i-1234567890abcdef0']
    assert mod.extract_instance_ids_from_createtags(
        {'detail': {'eventName': 'RunInstances'}}
    ) == []


def test_send_events_retries_then_succeeds(monkeypatch, aws):
    mod = load_handler_module('sec_meta_ec2_tags')
    monkeypatch.setenv('SPLUNK_HEC_HOST', 'https://splunk.example')
    monkeypatch.setenv('SPLUNK_HEC_TOKEN', 'hec-token')
    req = mod.build_hec_request()
    calls = []

    class _Success:
        def read(self):
            return b'{"text":"Success"}'

    def _urlopen(request, timeout):
        calls.append((request, timeout))
        if len(calls) == 1:
            raise urllib.error.URLError('temporary failure')
        return _Success()

    monkeypatch.setattr(mod.urllib.request, 'urlopen', _urlopen)
    monkeypatch.setattr(mod.time, 'sleep', lambda _seconds: None)
    monkeypatch.setattr(mod.random, 'random', lambda: 0)

    mod.send_events(req, ['{"event":1}'])

    assert len(calls) == 2
    assert calls[1][0].data == b'{"event":1}'


def test_lambda_handler_sends_metadata_for_created_instance_tags(
    monkeypatch, aws
):
    mod = load_handler_module('sec_meta_ec2_tags')
    ec2 = boto3.client('ec2', region_name=AWS_REGION)
    instance_id = ec2.run_instances(
        ImageId='ami-12345678',
        MinCount=1,
        MaxCount=1,
        InstanceType='t3.small',
    )['Instances'][0]['InstanceId']
    sent_batches = []
    monkeypatch.setenv('SPLUNK_DATA_MANAGER_INPUT_ID', 'dm-input-1')
    monkeypatch.setenv('SPLUNK_HEC_HOST', 'https://splunk.example')
    monkeypatch.setenv('SPLUNK_HEC_TOKEN', 'hec-token')
    monkeypatch.setattr(
        mod,
        'send_events',
        lambda _req, events: sent_batches.append(events),
    )

    result = mod.lambda_handler(_create_tags_event(instance_id), None)

    assert result is None
    assert len(sent_batches) == 1
    payload = json.loads(sent_batches[0][0])
    assert payload['sourcetype'] == 'aws:metadata'
    assert payload['source'] == f'123456789012:{AWS_REGION}:ec2_instances'
    assert payload['event']['InstanceId'] == instance_id
    assert payload['fields'] == {'data_manager_input_id': 'dm-input-1'}


def test_lambda_handler_noops_for_non_create_tags(monkeypatch, aws):
    mod = load_handler_module('sec_meta_ec2_tags')
    monkeypatch.setattr(
        mod,
        'send_events',
        lambda *_args, **_kwargs: (_ for _ in ()).throw(
            AssertionError('no event should be sent')
        ),
    )

    assert mod.lambda_handler(
        {'detail': {'eventName': 'RunInstances'}}, None) is None
