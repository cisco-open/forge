import json
from typing import Any, Dict, List

import boto3
from botocore.exceptions import ClientError
from trust_common import (LOG, assume_role, build_session_policy_for_tenants,
                          build_sts_client_from_creds, cleanup_forge_roles,
                          get_lambda_caller_identity)


def validate_prepared_forge_role_against_tenants(
    forge_role_arn: str,
    tenant_role_arns: List[str],
) -> Dict[str, Any]:
    """
    For a single Forge role:
      - assume forge role with a restrictive session policy
      - using that session, try to assume each tenant role
    """
    LOG.info(f'Starting validation for Forge role: {forge_role_arn}')
    result: Dict[str, Any] = {
        'forge_role_arn': forge_role_arn,
        'tenant_results': [],
        'errors': [],
    }

    try:
        session_policy = build_session_policy_for_tenants(tenant_role_arns)
        forge_assume_resp = assume_role(
            role_arn=forge_role_arn,
            session_name='ForgeValidation',
            session_policy=session_policy,
            retry_access_denied=True,
        )
        LOG.info(f'Successfully assumed Forge role: {forge_role_arn}')

        forge_creds = forge_assume_resp['Credentials']
        sts_as_forge = build_sts_client_from_creds(forge_creds)

        for tenant_arn in tenant_role_arns:
            LOG.info(
                'Attempting to assume Tenant role: %s from Forge role: %s',
                tenant_arn,
                forge_role_arn,
            )
            tenant_entry = {
                'tenant_role_arn': tenant_arn,
                'assume_role_success': False,
                'assume_role_error': None,
                'tag_session_success': False,
                'tag_session_error': None,
            }

            try:
                sts_as_forge.assume_role(
                    RoleArn=tenant_arn,
                    RoleSessionName='TenantValidation-Basic',
                )
                LOG.info(f'Basic AssumeRole successful for {tenant_arn}')
                tenant_entry['assume_role_success'] = True
            except ClientError as e:
                LOG.error(f'Basic AssumeRole failed for {tenant_arn}: {e}')
                tenant_entry['assume_role_error'] = str(e)
            except Exception as e:
                LOG.error(
                    'Unexpected error in Basic AssumeRole for %s: %s',
                    tenant_arn,
                    e,
                )
                tenant_entry['assume_role_error'] = f'Unexpected error: {e}'

            if tenant_entry['assume_role_success']:
                try:
                    tenant_resp = sts_as_forge.assume_role(
                        RoleArn=tenant_arn,
                        RoleSessionName='TenantValidation-Tags',
                        Tags=[
                            {
                                'Key': 'CreatedBy',
                                'Value': 'ForgeTrustValidator',
                            },
                            {'Key': 'Validation', 'Value': 'True'},
                        ],
                    )

                    tenant_creds = tenant_resp['Credentials']
                    sts_as_tenant = boto3.client(
                        'sts',
                        aws_access_key_id=tenant_creds['AccessKeyId'],
                        aws_secret_access_key=tenant_creds['SecretAccessKey'],
                        aws_session_token=tenant_creds['SessionToken'],
                    )
                    identity = sts_as_tenant.get_caller_identity()
                    LOG.info(
                        'AssumeRole WITH Tags successful for %s. Identity: %s',
                        tenant_arn,
                        identity['Arn'],
                    )

                    tenant_entry['tag_session_success'] = True
                except ClientError as e:
                    LOG.error(
                        'AssumeRole WITH Tags failed for %s: %s',
                        tenant_arn,
                        e,
                    )
                    tenant_entry['tag_session_error'] = str(e)
                except Exception as e:
                    LOG.error(
                        'Unexpected error in AssumeRole WITH Tags for %s: %s',
                        tenant_arn,
                        e,
                    )
                    tenant_entry['tag_session_error'] = (
                        f'Unexpected error: {e}'
                    )
            else:
                tenant_entry['tag_session_error'] = (
                    'Skipped because basic AssumeRole failed'
                )

            result['tenant_results'].append(tenant_entry)

    except ClientError as e:
        LOG.error(f'IAM/STS error for Forge role {forge_role_arn}: {e}')
        result['errors'].append(
            f'IAM/STS error for forge role {forge_role_arn}: {e}',
        )
    except Exception as e:
        LOG.error(f'Unexpected error for Forge role {forge_role_arn}: {e}')
        result['errors'].append(
            f'Unexpected error for forge role {forge_role_arn}: {e}',
        )

    return result


def validate_prepared_forge_roles(payload: Dict[str, Any]) -> Dict[str, Any]:
    run_id = str(payload.get('run_id', 'unknown'))
    forge_role_arns = [
        str(role_arn).strip()
        for role_arn in payload.get('forge_role_arns', [])
        if str(role_arn).strip()
    ]
    tenant_role_arns = [
        str(role_arn).strip()
        for role_arn in payload.get('tenant_role_arns', [])
        if str(role_arn).strip()
    ]

    if not forge_role_arns or not tenant_role_arns:
        raise RuntimeError(
            f'Delayed validation payload {run_id} is missing '
            'forge or tenant roles'
        )

    LOG.info(
        'Starting delayed validation run %s for %s Forge roles '
        'and %s Tenant roles',
        run_id,
        len(forge_role_arns),
        len(tenant_role_arns),
    )

    validation_results: List[Dict[str, Any]] = []
    cleanup_results: List[Dict[str, Any]] = []
    try:
        for forge_role_arn in forge_role_arns:
            validation_results.append(
                validate_prepared_forge_role_against_tenants(
                    forge_role_arn=forge_role_arn,
                    tenant_role_arns=tenant_role_arns,
                )
            )
    finally:
        cleanup_results = cleanup_forge_roles(forge_role_arns)

    result = {
        'phase': 'validate',
        'run_id': run_id,
        'validation_results': validation_results,
        'cleanup_results': cleanup_results,
    }
    LOG.info('Delayed validation run complete: %s', json.dumps(result))
    return result


def is_sqs_event(event: Any) -> bool:
    if not isinstance(event, dict):
        return False

    records = event.get('Records')
    if not isinstance(records, list) or not records:
        return False

    return all(record.get('eventSource') == 'aws:sqs' for record in records)


def handle_sqs_event(event: Dict[str, Any]) -> List[Dict[str, Any]]:
    results: List[Dict[str, Any]] = []
    for record in event['Records']:
        payload = json.loads(record['body'])
        if payload.get('phase') != 'validate':
            raise RuntimeError(
                f"Unsupported SQS validation phase: {payload.get('phase')}"
            )

        results.append(validate_prepared_forge_roles(payload))

    return results


def validate_handler(event, context):
    """
    Delayed validation Lambda entrypoint.

    This function is invoked by SQS after IAM/STS propagation time has elapsed.
    """
    try:
        LOG.info('Forge trust validator Lambda started')
        get_lambda_caller_identity()

        if is_sqs_event(event):
            sqs_results = handle_sqs_event(event)
            return {
                'statusCode': 200,
                'body': json.dumps(sqs_results),
            }

        raise RuntimeError(
            'Validator Lambda only accepts SQS validation events'
        )
    except Exception as e:
        LOG.exception(
            'Unhandled exception in forge_trust_validator lambda. Error: %s',
            e,
        )
        raise
