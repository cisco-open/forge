import json
import time
import uuid
from typing import Any, Dict, List

import boto3
from trust_common import (LOG, cleanup_forge_roles, get_lambda_caller_identity,
                          get_required_env, parse_env_int, parse_env_list,
                          prepare_temporary_forge_role_trust)

sqs = boto3.client('sqs')

DEFAULT_VALIDATION_DELAY_SECONDS = 300


def build_validation_payload(
    run_id: str,
    forge_role_arns: List[str],
    tenant_role_arns: List[str],
) -> Dict[str, Any]:
    return {
        'phase': 'validate',
        'run_id': run_id,
        'created_at_epoch': int(time.time()),
        'forge_role_arns': forge_role_arns,
        'tenant_role_arns': tenant_role_arns,
    }


def send_delayed_validation_message(
    queue_url: str,
    delay_seconds: int,
    payload: Dict[str, Any],
) -> Dict[str, Any]:
    LOG.info(
        'Scheduling delayed trust validation run %s in %s seconds',
        payload['run_id'],
        delay_seconds,
    )
    return sqs.send_message(
        QueueUrl=queue_url,
        DelaySeconds=delay_seconds,
        MessageBody=json.dumps(payload),
    )


def prepare_forge_roles_for_delayed_validation(
    forge_role_arns: List[str],
    tenant_role_arns: List[str],
    validator_lambda_role_arn: str,
    queue_url: str,
    delay_seconds: int,
    run_id: str,
) -> Dict[str, Any]:
    prepared_forge_role_arns: List[str] = []

    try:
        for forge_role_arn in forge_role_arns:
            prepare_temporary_forge_role_trust(
                forge_role_arn=forge_role_arn,
                lambda_role_arn=validator_lambda_role_arn,
            )
            prepared_forge_role_arns.append(forge_role_arn)

        payload = build_validation_payload(
            run_id=run_id,
            forge_role_arns=forge_role_arns,
            tenant_role_arns=tenant_role_arns,
        )
        send_response = send_delayed_validation_message(
            queue_url=queue_url,
            delay_seconds=delay_seconds,
            payload=payload,
        )

        return {
            'phase': 'prepare',
            'run_id': run_id,
            'validation_delay_seconds': delay_seconds,
            'prepared_forge_role_arns': prepared_forge_role_arns,
            'sqs_message_id': send_response.get('MessageId'),
        }
    except Exception:
        LOG.exception(
            'Prepare failed; removing temporary trust from prepared roles',
        )
        cleanup_results = cleanup_forge_roles(prepared_forge_role_arns)
        LOG.info(
            'Prepare phase cleanup results: %s',
            json.dumps(cleanup_results),
        )
        raise


def build_run_id(context: Any) -> str:
    request_id = getattr(context, 'aws_request_id', '')
    if request_id:
        return request_id

    return str(uuid.uuid4())


def prepare_handler(event, context):
    """
    Scheduled Lambda entrypoint.

    This function prepares trust for the validator Lambda, then schedules
    delayed validation through SQS.
    """
    try:
        LOG.info('Forge trust preparer Lambda started')
        get_lambda_caller_identity()

        forge_role_arns = parse_env_list('FORGE_IAM_ROLES')
        tenant_role_arns = parse_env_list('TENANT_IAM_ROLES')
        validator_lambda_role_arn = get_required_env(
            'VALIDATOR_LAMBDA_ROLE_ARN',
        )
        queue_url = get_required_env('VALIDATION_QUEUE_URL')
        delay_seconds = parse_env_int(
            name='VALIDATION_DELAY_SECONDS',
            default=DEFAULT_VALIDATION_DELAY_SECONDS,
            min_value=0,
            max_value=900,
        )

        if not forge_role_arns or not tenant_role_arns:
            raise RuntimeError(
                'Missing forge_role_arns or tenant_role_arns '
                '(check env variables FORGE_IAM_ROLES and TENANT_IAM_ROLES).'
            )

        LOG.info(
            'Loaded prepare configuration: %s Forge roles, %s Tenant roles, '
            'validator Lambda role %s',
            len(forge_role_arns),
            len(tenant_role_arns),
            validator_lambda_role_arn,
        )
        prepare_result = prepare_forge_roles_for_delayed_validation(
            forge_role_arns=forge_role_arns,
            tenant_role_arns=tenant_role_arns,
            validator_lambda_role_arn=validator_lambda_role_arn,
            queue_url=queue_url,
            delay_seconds=delay_seconds,
            run_id=build_run_id(context),
        )

        LOG.info('Prepare phase complete: %s', json.dumps(prepare_result))

        return {
            'statusCode': 200,
            'body': json.dumps(prepare_result),
        }
    except Exception as e:
        LOG.exception(
            'Unhandled exception in forge_trust_preparer lambda. Error: %s',
            e,
        )
        raise
