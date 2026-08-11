"""Tag or delete log groups for Splunk Data Manager Lambda functions."""

from __future__ import annotations

import logging
import os
import re
from typing import Any

import boto3
from botocore.config import Config
from botocore.exceptions import ClientError

LOG = logging.getLogger()
LOG.setLevel(os.environ.get('LOG_LEVEL', 'INFO').upper())

ACCOUNT_ID = os.environ['EXPECTED_ACCOUNT_ID']
PARTITION = os.environ['EXPECTED_PARTITION']
REGION = os.environ['EXPECTED_REGION']
FUNCTION_PREFIX = os.environ.get('FUNCTION_NAME_PREFIX', 'SplunkDM')
FUNCTION_NAME_PATTERN = re.compile(r'^[A-Za-z0-9-_]{1,64}$')


def _error_code(error: ClientError) -> str:
    return error.response.get('Error', {}).get('Code', '')


def discover_function_names(
    stack_ids: Any,
    cloudformation_client: Any,
) -> list[str]:
    """Return physical Lambda names from supplied and nested stacks."""
    if not isinstance(stack_ids, list) or not all(
        isinstance(stack_id, str) for stack_id in stack_ids
    ):
        raise ValueError('stack_ids must be a JSON list of strings')

    function_names: set[str] = set()
    pending = sorted(set(stack_ids))
    visited: set[str] = set()
    paginator = cloudformation_client.get_paginator('list_stack_resources')

    while pending:
        stack_id = pending.pop()
        if stack_id in visited:
            continue

        parts = stack_id.split(':', 5)
        resource = parts[5].split('/') if len(parts) == 6 else []
        valid_stack = all((
            len(parts) == 6,
            parts[:3] == ['arn', PARTITION, 'cloudformation'],
            parts[3:5] == [REGION, ACCOUNT_ID],
            len(resource) == 3,
            resource[0] == 'stack',
            resource[1].startswith('SplunkDM'),
        ))
        if not valid_stack:
            raise ValueError(
                f'Stack is outside the helper scope: {stack_id!r}'
            )
        visited.add(stack_id)

        for page in paginator.paginate(StackName=stack_id):
            for item in page.get('StackResourceSummaries', []):
                resource_type = item.get('ResourceType')
                physical_id = item.get('PhysicalResourceId')
                if resource_type == 'AWS::CloudFormation::Stack':
                    if isinstance(physical_id, str):
                        pending.append(physical_id)
                elif all((
                    resource_type == 'AWS::Lambda::Function',
                    isinstance(physical_id, str) and physical_id.startswith(
                        FUNCTION_PREFIX),
                )):
                    function_names.add(physical_id)
    return sorted(function_names)


def reconcile(
    event: dict[str, Any],
    cloudformation_client: Any,
    logs_client: Any,
) -> dict[str, Any]:
    """Create and tag the default groups for discovered Lambda functions."""
    if event.get('region', REGION) != REGION:
        raise ValueError('Event region does not match the helper region')
    tags = event.get('tags')
    if not isinstance(tags, dict) or len(tags) > 50:
        raise ValueError('tags must contain at most 50 valid string entries')
    for key, value in tags.items():
        if not isinstance(key, str) or not isinstance(value, str):
            raise ValueError(
                'tags must contain at most 50 valid string entries'
            )
        if not key or key.casefold().startswith('aws:'):
            raise ValueError(
                'tags must contain at most 50 valid string entries'
            )

    function_names = discover_function_names(
        event.get('stack_ids'),
        cloudformation_client,
    )
    created = 0
    for function_name in function_names:
        group_name = f'/aws/lambda/{function_name}'
        try:
            logs_client.create_log_group(logGroupName=group_name)
            created += 1
        except ClientError as error:
            if _error_code(error) != 'ResourceAlreadyExistsException':
                raise
        if tags:
            logs_client.tag_resource(
                resourceArn=(
                    f'arn:{PARTITION}:logs:{REGION}:{ACCOUNT_ID}:'
                    f'log-group:{group_name}'
                ),
                tags=tags,
            )
    return {
        'action': 'reconcile',
        'functions': len(function_names),
        'log_groups_created': created,
        'log_groups_tagged': len(function_names) if tags else 0,
    }


def delete_log_group(
    event: dict[str, Any],
    logs_client: Any,
) -> dict[str, Any]:
    """Delete the group named by one Lambda DeleteFunction event."""
    detail = event.get('detail')
    valid_event = isinstance(detail, dict) and all((
        event.get('source') == 'aws.lambda',
        event.get('detail-type') == 'AWS API Call via CloudTrail',
        event.get('account') == ACCOUNT_ID,
        event.get('region') == REGION,
        detail.get('eventSource') == 'lambda.amazonaws.com',
        detail.get('eventName') == 'DeleteFunction20150331',
        'errorCode' not in detail,
    ))
    if not valid_event:
        raise ValueError('Unsupported Lambda deletion event')

    request = detail.get('requestParameters')
    function_name = (
        request.get('functionName') if isinstance(request, dict) else None
    )
    if not isinstance(function_name, str) or request.get('qualifier') is not None:
        raise ValueError('Unsupported DeleteFunction parameters')

    arn_prefix = f'arn:{PARTITION}:lambda:{REGION}:{ACCOUNT_ID}:function:'
    if function_name.startswith('arn:'):
        if not function_name.startswith(arn_prefix):
            raise ValueError('Lambda ARN is outside the helper scope')
        function_name = function_name.removeprefix(arn_prefix)
    if not function_name.startswith(FUNCTION_PREFIX) or not FUNCTION_NAME_PATTERN.fullmatch(function_name):
        raise ValueError('Lambda name is outside the helper scope')

    group_name = f'/aws/lambda/{function_name}'
    try:
        logs_client.delete_log_group(logGroupName=group_name)
        deleted = True
    except ClientError as error:
        if _error_code(error) not in {
            'ResourceNotFoundException',
            'ResourceNotFound',
        }:
            raise
        deleted = False
    return {
        'action': 'delete',
        'log_group_name': group_name,
        'deleted': deleted,
    }


def lambda_handler(event: dict[str, Any], _context: Any) -> dict[str, Any]:
    if not isinstance(event, dict):
        raise ValueError('event must be a JSON object')

    config = Config(retries={'max_attempts': 8, 'mode': 'standard'})
    logs_client = boto3.client('logs', config=config)
    if event.get('source') == 'aws.lambda':
        result = delete_log_group(event, logs_client)
    else:
        result = reconcile(
            event,
            boto3.client('cloudformation', config=config),
            logs_client,
        )
    LOG.info('Completed Splunk log-group action: %s', result)
    return result
