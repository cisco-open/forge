import json
import os
import time
from typing import Any, Dict, List

import boto3
from botocore.exceptions import ClientError

iam = boto3.client('iam')
sts = boto3.client('sts')


def parse_env_list(name: str) -> List[str]:
    value = os.environ.get(name, '')
    if not value:
        return []

    # Try parsing as JSON first (in case it's a JSON list string like '["a", "b"]')
    try:
        parsed = json.loads(value)
        if isinstance(parsed, list):
            return [str(v).strip() for v in parsed if str(v).strip()]
    except json.JSONDecodeError:
        pass

    # Support comma, whitespace
    return [v.strip() for v in value.split(',') if v.strip()]


def build_session_policy_for_tenants(tenant_role_arns: List[str]) -> str:
    """
    Build a restrictive inline session policy that only allows sts:AssumeRole
    on the tenant roles. This means our assumed Forge-role session won’t be
    able to do anything else.
    """
    policy = {
        'Version': '2012-10-17',
        'Statement': [
            {
                'Sid': 'AllowAssumeTenantRolesForValidation',
                'Effect': 'Allow',
                'Action': 'sts:AssumeRole',
                'Resource': tenant_role_arns
            }
        ]
    }
    return json.dumps(policy)


def add_lambda_to_trust_policy(
    role_name: str,
    lambda_role_arn: str
) -> Dict[str, Any]:
    """
    Fetches the current assume-role policy for the Forge role,
    adds Lambda role as a trusted principal, and updates the role.

    Returns the original assume-role policy document so we can restore it later.
    """
    role = iam.get_role(RoleName=role_name)
    original_policy = role['Role']['AssumeRolePolicyDocument']

    # Shallow copy to avoid mutating original we’ll return
    new_policy = json.loads(json.dumps(original_policy))

    statement = {
        'Sid': 'AllowLambdaValidationAssume',
        'Effect': 'Allow',
        'Principal': {'AWS': lambda_role_arn},
        'Action': 'sts:AssumeRole'
    }

    # Append statement (avoid duplicates if already exists)
    statements = new_policy.get('Statement', [])
    if not any(
        s.get('Sid') == statement['Sid'] and s.get(
            'Principal', {}).get('AWS') == lambda_role_arn
        for s in statements
    ):
        statements.append(statement)
        new_policy['Statement'] = statements

    iam.update_assume_role_policy(
        RoleName=role_name,
        PolicyDocument=json.dumps(new_policy)
    )

    return original_policy


def restore_trust_policy(role_name: str, original_policy: Dict[str, Any]) -> None:
    iam.update_assume_role_policy(
        RoleName=role_name,
        PolicyDocument=json.dumps(original_policy)
    )


def assume_role(
    role_arn: str,
    session_name: str,
    session_policy: str | None = None
) -> Dict[str, Any]:
    """
    Wrapper around sts.assume_role that optionally applies a restrictive session policy.
    """
    kwargs = {
        'RoleArn': role_arn,
        'RoleSessionName': session_name,
        'DurationSeconds': 900,  # 15 mins, we won't use that long
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
    lambda_role_arn: str
) -> Dict[str, Any]:
    """
    Core logic for one Forge role:
      - Temporarily add Lambda role to trust policy
      - Assume Forge role with restricted session policy
      - From that session, try to assume each tenant role
      - Restore trust policy
      - Return per-tenant results
    """
    role_name = forge_role_arn.split('/')[-1]

    result = {
        'forge_role_arn': forge_role_arn,
        'tenant_results': [],
        'errors': []
    }

    try:
        # 1. Update trust policy (allow Lambda to assume the forge role temporarily)
        original_policy = add_lambda_to_trust_policy(
            role_name, lambda_role_arn)

        try:
            # 2. Assume the Forge role with restricted policy
            session_policy = build_session_policy_for_tenants(tenant_role_arns)
            forge_assume_resp = assume_role(
                role_arn=forge_role_arn,
                session_name=f"ForgeValidation-{int(time.time())}",
                session_policy=session_policy
            )

            forge_creds = forge_assume_resp['Credentials']
            sts_as_forge = build_sts_client_from_creds(forge_creds)

            # 3. For each tenant role, try to AssumeRole using the forge session
            for tenant_arn in tenant_role_arns:
                tenant_entry = {
                    'tenant_role_arn': tenant_arn,
                    'success': False,
                    'error': None
                }
                try:
                    tenant_resp = sts_as_forge.assume_role(
                        RoleArn=tenant_arn,
                        RoleSessionName=f"TenantValidation-{int(time.time())}"
                    )

                    # Optionally verify we can call GetCallerIdentity with tenant creds
                    tenant_creds = tenant_resp['Credentials']
                    sts_as_tenant = boto3.client(
                        'sts',
                        aws_access_key_id=tenant_creds['AccessKeyId'],
                        aws_secret_access_key=tenant_creds['SecretAccessKey'],
                        aws_session_token=tenant_creds['SessionToken'],
                    )
                    sts_as_tenant.get_caller_identity()

                    tenant_entry['success'] = True
                except ClientError as e:
                    tenant_entry['error'] = str(e)
                except Exception as e:
                    tenant_entry['error'] = f"Unexpected error assuming tenant role: {e}"

                result['tenant_results'].append(tenant_entry)

        finally:
            # 4. Restore original trust policy regardless of outcome
            try:
                restore_trust_policy(role_name, original_policy)
            except Exception as e:
                # Capture but don't crash everything
                result['errors'].append(
                    f"Failed to restore trust policy for {role_name}: {e}"
                )

    except ClientError as e:
        result['errors'].append(
            f"IAM/STS error for forge role {forge_role_arn}: {e}")
    except Exception as e:
        result['errors'].append(
            f"Unexpected error for forge role {forge_role_arn}: {e}")

    return result


def lambda_handler(event, context):
    """
    Main Lambda entrypoint.

    Input options:
      - Uses environment variables FORGE_ROLE_ARNS and TENANT_ROLE_ARNS
      - Optionally can accept same lists via the event:
        {
          "forge_role_arns": ["..."],
          "tenant_role_arns": ["..."]
        }
    """
    forge_iam_roles = parse_env_list('FORGE_IAM_ROLES')
    tenant_iam_roles = parse_env_list('TENANT_IAM_ROLES')
    lambda_role_arn = os.environ['LAMBDA_EXECUTION_ROLE_ARN']

    if not forge_iam_roles or not tenant_iam_roles:
        return {
            'statusCode': 400,
            'body': json.dumps({
                'message': 'Missing forge_iam_roles or tenant_iam_roles (check event or env variables).'
            })
        }

    all_results = []

    for forge_arn in forge_iam_roles:
        res = validate_forge_role_against_tenants(
            forge_role_arn=forge_arn,
            tenant_role_arns=tenant_iam_roles,
            lambda_role_arn=lambda_role_arn
        )
        all_results.append(res)

    # For now, we just log & return. You can push to S3 or DynamoDB instead.
    print(json.dumps(all_results, indent=2))

    return {
        'statusCode': 200,
        'body': json.dumps(all_results)
    }
