"""Runner AMI SSM updater Lambda tests."""

from __future__ import annotations

import json

import pytest
from conftest import requires_aws
from support import load_handler_module

pytestmark = requires_aws


def _runner_map(ssm_id='/forge/runner/ami'):
    return {
        'linux-small': {
            'ssm_id': ssm_id,
            'ami_filter': {'name': ['forge-runner-*']},
            'ami_owners': ['self'],
        },
    }


def test_updates_ssm_to_latest_matching_ami(monkeypatch, ssm):
    mod = load_handler_module('ec2_update_runner_ssm_ami')
    ssm['client'].put_parameter(
        Name='/forge/runner/ami',
        Value='ami-old',
        Type='String',
    )
    monkeypatch.setenv('RUNNER_AMI_MAP', json.dumps(_runner_map()))
    monkeypatch.setattr(
        mod.ec2,
        'describe_images',
        lambda **kwargs: {
            'Images': [
                {
                    'ImageId': 'ami-older',
                    'Name': 'forge-runner-older',
                    'CreationDate': '2026-01-01T00:00:00.000Z',
                },
                {
                    'ImageId': 'ami-newer',
                    'Name': 'forge-runner-newer',
                    'CreationDate': '2026-02-01T00:00:00.000Z',
                },
            ],
        },
    )

    result = mod.lambda_handler({}, None)

    assert result['statusCode'] == 200
    param = ssm['client'].get_parameter(Name='/forge/runner/ami')
    assert param['Parameter']['Value'] == 'ami-newer'
    tags = {
        tag['Key']: tag['Value']
        for tag in ssm['client'].list_tags_for_resource(
            ResourceType='Parameter',
            ResourceId='/forge/runner/ami',
        )['TagList']
    }
    assert tags == {
        'ghr:ami_name': 'forge-runner-newer',
        'ghr:ami_creation_date': '2026-02-01T00:00:00.000Z',
    }


def test_no_matching_images_is_successful_noop(monkeypatch, ssm):
    mod = load_handler_module('ec2_update_runner_ssm_ami')
    monkeypatch.setenv('RUNNER_AMI_MAP', json.dumps(_runner_map()))
    monkeypatch.setattr(mod.ec2, 'describe_images',
                        lambda **_kwargs: {'Images': []})
    monkeypatch.setattr(
        mod.ssm,
        'put_parameter',
        lambda **_kwargs: (_ for _ in ()).throw(
            AssertionError('no AMI means no SSM write')
        ),
    )

    result = mod.lambda_handler({}, None)

    assert result['statusCode'] == 200


def test_missing_ssm_parameter_raises(monkeypatch, ssm):
    mod = load_handler_module('ec2_update_runner_ssm_ami')
    monkeypatch.setenv('RUNNER_AMI_MAP', json.dumps(_runner_map()))
    monkeypatch.setattr(
        mod.ec2,
        'describe_images',
        lambda **_kwargs: {
            'Images': [
                {
                    'ImageId': 'ami-newer',
                    'Name': 'forge-runner-newer',
                    'CreationDate': '2026-02-01T00:00:00.000Z',
                },
            ],
        },
    )

    with pytest.raises(RuntimeError, match='SSM parameter not found'):
        mod.lambda_handler({}, None)
