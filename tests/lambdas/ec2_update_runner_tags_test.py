"""EC2 runner job-tagging Lambda tests."""

from __future__ import annotations

import json

import boto3
import pytest
from conftest import AWS_REGION, requires_aws
from support import load_handler_module

pytestmark = requires_aws


def _event(runner_name):
    return {
        'detail-type': 'workflow_job',
        'detail': {
            'workflow_job': {
                'runner_name': runner_name,
                'html_url': 'https://github.com/acme/app/actions/runs/1/job/2',
                'id': 2,
            },
        },
    }


def test_non_workflow_job_event_is_ignored(monkeypatch, aws):
    mod = load_handler_module('ec2_update_runner_tags')

    result = mod.lambda_handler({'detail-type': 'push'}, None)

    assert result['statusCode'] == 200
    assert json.loads(result['body']) == {'message': 'ignored event'}


def test_non_ec2_runner_name_is_ignored(monkeypatch, aws):
    mod = load_handler_module('ec2_update_runner_tags')

    result = mod.lambda_handler(_event('hosted-runner-1'), None)

    assert result['statusCode'] == 200
    assert json.loads(result['body']) == {'message': 'ignored non-EC2 runner'}


def test_missing_runner_name_raises(monkeypatch, aws):
    mod = load_handler_module('ec2_update_runner_tags')

    with pytest.raises(ValueError, match='runner_name missing'):
        mod.lambda_handler(_event(''), None)


def test_ec2_runner_instance_is_tagged_with_job_metadata(monkeypatch, aws):
    mod = load_handler_module('ec2_update_runner_tags')
    ec2 = boto3.client('ec2', region_name=AWS_REGION)
    instance_id = ec2.run_instances(
        ImageId='ami-12345678',
        MinCount=1,
        MaxCount=1,
        InstanceType='t3.small',
    )['Instances'][0]['InstanceId']

    result = mod.lambda_handler(_event(instance_id), None)

    assert result['statusCode'] == 200
    assert json.loads(result['body']) == {'tagged_instances': [instance_id]}
    instance = ec2.describe_instances(InstanceIds=[instance_id])[
        'Reservations'
    ][0]['Instances'][0]
    tags = {tag['Key']: tag['Value'] for tag in instance['Tags']}
    assert tags['ghr:job_id'] == '2'
    assert tags['ghr:job_url'] == (
        'https://github.com/acme/app/actions/runs/1/job/2'
    )
