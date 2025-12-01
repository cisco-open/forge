import json
import logging
import os
import time
from typing import Any, Dict, List

import boto3
from botocore.exceptions import ClientError

sts = boto3.client('sts')

LOG = logging.getLogger()
level_str = os.environ.get('LOG_LEVEL', 'INFO').upper()
LOG.setLevel(getattr(logging, level_str, logging.INFO))


def parse_env_list(name: str) -> List[str]:
    """
    Parse an environment variable Comma-separated string: 'a,b'
    """
    LOG.info(f"Parsing environment variable: {name}")
    value = os.environ.get(name, '')
    if not value:
        LOG.warning(f"Environment variable {name} is empty or missing")
        return []

    items = [v.strip() for v in value.split(',') if v.strip()]
    LOG.info(f"Parsed {len(items)} items from {name}")
    return items


def build_session_policy_for_tenants(tenant_role_arns: List[str]) -> str:
    """
    Restrictive inline session policy: only allow sts:AssumeRole on tenant roles.
    This means the forge-role session can't do anything else.
    """
    policy = {
        'Version': '2012-10-17',
        'Statement': [
            {
                'Sid': 'AllowAssumeTenantRolesForValidation',
                'Effect': 'Allow',
                'Action': 'sts:AssumeRole',
                'Resource': tenant_role_arns,
            }
        ],
    }
    return json.dumps(policy)


def assume_role(
    role_arn: str,
    session_name: str,
    session_policy: str | None = None,
) -> Dict[str, Any]:
    """
    Wrapper around sts.assume_role that optionally applies a restrictive session policy.
    """
    LOG.info(
        f"Attempting to assume role: {role_arn} (Session: {session_name})")
    kwargs: Dict[str, Any] = {
        'RoleArn': role_arn,
        'RoleSessionName': session_name,
        'DurationSeconds': 900,  # 15 minutes is plenty for validation
    }
    if session_policy:
        kwargs['Policy'] = session_policy

    return sts.assume_role(**kwargs)


def build_sts_client_from_creds(creds: Dict[str, Any]):
    """
    Given STS credentials from assume_role, build an STS client using them.
    """
    return boto3.client(
        'sts',
        aws_access_key_id=creds['AccessKeyId'],
        aws_secret_access_key=creds['SecretAccessKey'],
        aws_session_token=creds['SessionToken'],
    )


def validate_forge_role_against_tenants(
    forge_role_arn: str,
    tenant_role_arns: List[str],
) -> Dict[str, Any]:
    """
    For a single Forge role:
      - assume forge role (with restrictive session policy)
      - using that session, try to assume each tenant role
      - return per-tenant results
    Assumes:
      - Lambda execution role already has sts:AssumeRole on forge_role_arn
      - Forge role trust already allows the Lambda execution role
    """
    LOG.info(f"Starting validation for Forge role: {forge_role_arn}")
    result: Dict[str, Any] = {
        'forge_role_arn': forge_role_arn,
        'tenant_results': [],
        'errors': [],
    }

    try:
        # 1) Assume the Forge role with a restrictive policy
        session_policy = build_session_policy_for_tenants(tenant_role_arns)
        forge_assume_resp = assume_role(
            role_arn=forge_role_arn,
            session_name=f"ForgeValidation-{int(time.time())}",
            session_policy=session_policy,
        )
        LOG.info(f"Successfully assumed Forge role: {forge_role_arn}")

        forge_creds = forge_assume_resp['Credentials']
        sts_as_forge = build_sts_client_from_creds(forge_creds)

        # 2) From the forge session, attempt to assume each tenant role
        for tenant_arn in tenant_role_arns:
            LOG.info(
                f"Attempting to assume Tenant role: {tenant_arn} from Forge role: {forge_role_arn}")
            tenant_entry = {
                'tenant_role_arn': tenant_arn,
                'success': False,
                'error': None,
            }
            try:
                tenant_resp = sts_as_forge.assume_role(
                    RoleArn=tenant_arn,
                    RoleSessionName=f"TenantValidation-{int(time.time())}",
                )

                # Optional: verify the tenant creds actually work
                tenant_creds = tenant_resp['Credentials']
                sts_as_tenant = boto3.client(
                    'sts',
                    aws_access_key_id=tenant_creds['AccessKeyId'],
                    aws_secret_access_key=tenant_creds['SecretAccessKey'],
                    aws_session_token=tenant_creds['SessionToken'],
                )
                identity = sts_as_tenant.get_caller_identity()
                LOG.info(
                    f"Successfully assumed Tenant role: {tenant_arn}. Identity: {identity['Arn']}")

                tenant_entry['success'] = True
            except ClientError as e:
                LOG.error(
                    f"ClientError assuming Tenant role {tenant_arn}: {e}")
                tenant_entry['error'] = str(e)
            except Exception as e:
                LOG.error(
                    f"Unexpected error assuming Tenant role {tenant_arn}: {e}")
                tenant_entry['error'] = f"Unexpected error assuming tenant role: {e}"

            result['tenant_results'].append(tenant_entry)

    except ClientError as e:
        LOG.error(f"IAM/STS error for Forge role {forge_role_arn}: {e}")
        result['errors'].append(
            f"IAM/STS error for forge role {forge_role_arn}: {e}"
        )
    except Exception as e:
        LOG.error(f"Unexpected error for Forge role {forge_role_arn}: {e}")
        result['errors'].append(
            f"Unexpected error for forge role {forge_role_arn}: {e}"
        )

    return result


def lambda_handler(event, context):
    """
    Main Lambda entrypoint.

    Configuration:
      - FORGE_IAM_ROLES: env var, JSON list or CSV of forge role ARNs
      - TENANT_IAM_ROLES: env var, JSON list or CSV of tenant role ARNs

    Example:
      FORGE_IAM_ROLES='["arn:aws:iam::123:role/forge-1","arn:aws:iam::123:role/forge-2"]'
      TENANT_IAM_ROLES="arn:aws:iam::456:role/tenant-1,arn:aws:iam::789:role/tenant-2"
    """
    LOG.info('Lambda handler started')
    forge_iam_roles = parse_env_list('FORGE_IAM_ROLES')
    tenant_iam_roles = parse_env_list('TENANT_IAM_ROLES')

    if not forge_iam_roles or not tenant_iam_roles:
        LOG.error(
            'Missing required environment variables: FORGE_IAM_ROLES or TENANT_IAM_ROLES')
        return {
            'statusCode': 400,
            'body': json.dumps(
                {
                    'message': (
                        'Missing forge_iam_roles or tenant_iam_roles '
                        '(check env variables FORGE_IAM_ROLES and TENANT_IAM_ROLES).'
                    )
                }
            ),
        }

    LOG.info(
        f"Loaded configuration: {len(forge_iam_roles)} Forge roles, {len(tenant_iam_roles)} Tenant roles")
    all_results: List[Dict[str, Any]] = []

    for forge_arn in forge_iam_roles:
        res = validate_forge_role_against_tenants(
            forge_role_arn=forge_arn,
            tenant_role_arns=tenant_iam_roles,
        )
        all_results.append(res)

    LOG.info('Validation complete')
    print(json.dumps(all_results, indent=2))

    return {
        'statusCode': 200,
        'body': json.dumps(all_results),
    }
