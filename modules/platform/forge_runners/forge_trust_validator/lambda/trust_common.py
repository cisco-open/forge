import copy
import json
import logging
import os
import random
import time
from typing import Any, Callable, Dict, List

import boto3
from botocore.exceptions import ClientError

iam = boto3.client('iam')
sts = boto3.client('sts')

TRUST_STATEMENT_SID = 'AllowLambdaValidationAssume'
IAM_UPDATE_MAX_ATTEMPTS = 10
FORGE_ASSUME_MAX_ATTEMPTS = 6
TRUST_POLICY_VERIFY_MAX_ATTEMPTS = 6
RETRYABLE_CLIENT_ERROR_CODES = {
    'LimitExceeded',
    'RequestLimitExceeded',
    'ServiceFailure',
    'ThrottledException',
    'Throttling',
    'ThrottlingException',
    'TooManyRequestsException',
}

LOG = logging.getLogger()
level_str = os.environ.get('LOG_LEVEL', 'INFO').upper()
LOG.setLevel(getattr(logging, level_str, logging.INFO))


def parse_env_list(name: str) -> List[str]:
    """
    Parse an environment variable containing either a JSON list or CSV values.
    """
    LOG.info(f'Parsing environment variable: {name}')
    value = os.environ.get(name, '').strip()
    if not value:
        LOG.warning(f'Environment variable {name} is empty or missing')
        return []

    if value.startswith('['):
        try:
            parsed = json.loads(value)
            if isinstance(parsed, list):
                items = [str(v).strip() for v in parsed if str(v).strip()]
                LOG.info(f'Parsed {len(items)} JSON items from {name}')
                return items

            LOG.warning(
                'Environment variable %s looked like JSON but was not a list',
                name,
            )
        except json.JSONDecodeError as e:
            LOG.warning(
                'Failed to parse %s as JSON; falling back to CSV: %s',
                name,
                e,
            )

    items = [v.strip() for v in value.split(',') if v.strip()]
    LOG.info(f'Parsed {len(items)} CSV items from {name}')
    return items


def parse_env_int(
    name: str,
    default: int,
    min_value: int,
    max_value: int,
) -> int:
    value = os.environ.get(name, '').strip()
    if not value:
        return default

    try:
        parsed = int(value)
    except ValueError as e:
        raise RuntimeError(
            f'Environment variable {name} must be an integer') from e

    if parsed < min_value or parsed > max_value:
        raise RuntimeError(
            f'Environment variable {name} must be between '
            f'{min_value} and {max_value}'
        )

    return parsed


def get_required_env(name: str) -> str:
    value = os.environ.get(name, '').strip()
    if not value:
        raise RuntimeError(f'Missing required environment variable: {name}')
    return value


def get_forge_role_name(role_arn: str) -> str:
    """
    Extract the IAM RoleName from an ARN.
    """
    return role_arn.rsplit('/', 1)[-1]


def is_retryable_client_error(
    error: ClientError,
    retry_access_denied: bool = False,
) -> bool:
    error_details = error.response.get('Error', {})
    code = error_details.get('Code', '')
    message = error_details.get('Message', '')

    if code in RETRYABLE_CLIENT_ERROR_CODES or 'Rate exceeded' in message:
        return True

    # IAM trust policy changes are eventually consistent. Immediately
    # after adding the trust statement, STS can briefly return AccessDenied.
    access_denied_codes = {'AccessDenied', 'AccessDeniedException'}
    if retry_access_denied and code in access_denied_codes:
        return True

    return False


def call_with_backoff(
    operation_name: str,
    operation: Callable[[], Any],
    max_attempts: int,
    retry_access_denied: bool = False,
) -> Any:
    attempt = 1
    delay = 2.0

    while True:
        try:
            return operation()
        except ClientError as e:
            if attempt >= max_attempts or not is_retryable_client_error(
                e,
                retry_access_denied=retry_access_denied,
            ):
                raise

            sleep_for = delay + random.uniform(0, 0.5)
            error_details = e.response.get('Error', {})
            LOG.warning(
                'Retrying %s after AWS error %s on attempt %s/%s; '
                'sleeping %.2fs',
                operation_name,
                error_details.get('Code', 'Unknown'),
                attempt,
                max_attempts,
                sleep_for,
            )
            time.sleep(sleep_for)
            attempt += 1
            delay = min(delay * 2, 30.0)


def normalize_policy_document(policy_document: Any) -> Dict[str, Any]:
    """
    Normalize IAM policy JSON into a mutable dict with Statement as a list.
    """
    if isinstance(policy_document, str):
        policy = json.loads(policy_document)
    else:
        policy = copy.deepcopy(policy_document)

    if not isinstance(policy, dict):
        raise ValueError(
            'IAM assume role policy document must be a JSON object')

    statements = policy.get('Statement', [])
    if isinstance(statements, dict):
        statements = [statements]
    elif statements is None:
        statements = []
    elif not isinstance(statements, list):
        raise ValueError(
            'IAM assume role policy Statement must be a list or object')

    policy['Version'] = policy.get('Version', '2012-10-17')
    policy['Statement'] = statements
    return policy


def policy_document_to_log_json(policy_document: Any) -> str:
    return json.dumps(
        normalize_policy_document(policy_document),
        sort_keys=True,
    )


def log_trust_policy(
    role_name: str,
    stage: str,
    policy_document: Any,
) -> None:
    LOG.info(
        'Forge role %s trust policy %s: %s',
        role_name,
        stage,
        policy_document_to_log_json(policy_document),
    )


def build_lambda_trust_statement(lambda_role_arn: str) -> Dict[str, Any]:
    return {
        'Sid': TRUST_STATEMENT_SID,
        'Effect': 'Allow',
        'Principal': {
            'AWS': lambda_role_arn,
        },
        'Action': 'sts:AssumeRole',
    }


def is_validator_trust_statement(statement: Any) -> bool:
    if not isinstance(statement, dict):
        return False

    return statement.get('Sid') == TRUST_STATEMENT_SID


def listify(value: Any) -> List[Any]:
    if isinstance(value, list):
        return value
    if value is None:
        return []
    return [value]


def validator_trust_statement_matches(
    statement: Any,
    lambda_role_arn: str,
) -> bool:
    if not is_validator_trust_statement(statement):
        return False
    if statement.get('Effect') != 'Allow':
        return False

    principals = statement.get('Principal', {})
    if not isinstance(principals, dict):
        return False

    actions = listify(statement.get('Action'))
    aws_principals = listify(principals.get('AWS'))

    if 'sts:AssumeRole' not in actions:
        return False

    return lambda_role_arn in aws_principals


def policy_has_validator_trust(
    policy_document: Any,
    lambda_role_arn: str,
) -> bool:
    policy = normalize_policy_document(policy_document)
    return any(
        validator_trust_statement_matches(statement, lambda_role_arn)
        for statement in policy['Statement']
    )


def get_role_assume_policy(role_name: str) -> Dict[str, Any]:
    role_response = call_with_backoff(
        operation_name=f'get role {role_name}',
        operation=lambda: iam.get_role(RoleName=role_name),
        max_attempts=3,
    )
    return role_response['Role']['AssumeRolePolicyDocument']


def wait_for_temporary_forge_role_trust(
    role_name: str,
    lambda_role_arn: str,
) -> Dict[str, Any]:
    delay = 2.0

    for attempt in range(1, TRUST_POLICY_VERIFY_MAX_ATTEMPTS + 1):
        policy_document = get_role_assume_policy(role_name)
        if policy_has_validator_trust(policy_document, lambda_role_arn):
            LOG.info(
                'Verified temporary trust statement on Forge role %s for %s',
                role_name,
                lambda_role_arn,
            )
            return policy_document

        if attempt == TRUST_POLICY_VERIFY_MAX_ATTEMPTS:
            break

        LOG.warning(
            'Temporary trust statement is not visible on Forge role %s '
            'after update attempt %s/%s; sleeping %.2fs',
            role_name,
            attempt,
            TRUST_POLICY_VERIFY_MAX_ATTEMPTS,
            delay,
        )
        time.sleep(delay)
        delay = min(delay * 2, 30.0)

    raise RuntimeError(
        f'Temporary trust statement was not visible on Forge role {role_name} '
        f'for Lambda role {lambda_role_arn}'
    )


def remove_validator_trust_statement(policy_document: Any) -> Dict[str, Any]:
    """
    Remove the validator-owned trust statement from a policy document.

    This also cleans up stale statements previously added by Terraform.
    """
    policy = normalize_policy_document(policy_document)
    original_count = len(policy['Statement'])
    policy['Statement'] = [
        statement for statement in policy['Statement']
        if not is_validator_trust_statement(statement)
    ]
    removed_count = original_count - len(policy['Statement'])
    if removed_count:
        LOG.info(
            'Removed %s stale validator trust statement(s) from base policy',
            removed_count,
        )

    return policy


def policy_has_validator_statement(policy_document: Any) -> bool:
    policy = normalize_policy_document(policy_document)
    return any(
        is_validator_trust_statement(statement)
        for statement in policy['Statement']
    )


def build_temporary_forge_trust_policy(
    base_policy: Dict[str, Any],
    lambda_role_arn: str,
) -> Dict[str, Any]:
    policy = remove_validator_trust_statement(base_policy)
    policy['Statement'].append(build_lambda_trust_statement(lambda_role_arn))
    return policy


def update_assume_role_policy(
    role_name: str,
    policy_document: Dict[str, Any],
) -> None:
    policy_json = json.dumps(policy_document)
    call_with_backoff(
        operation_name=f'update assume role policy for {role_name}',
        operation=lambda: iam.update_assume_role_policy(
            RoleName=role_name,
            PolicyDocument=policy_json,
        ),
        max_attempts=IAM_UPDATE_MAX_ATTEMPTS,
    )


def prepare_temporary_forge_role_trust(
    forge_role_arn: str,
    lambda_role_arn: str,
) -> None:
    role_name = get_forge_role_name(forge_role_arn)
    LOG.info(
        'Preparing temporary trust statement for Forge role: %s',
        forge_role_arn,
    )

    current_policy = get_role_assume_policy(role_name)
    log_trust_policy(role_name, 'before update', current_policy)
    temporary_policy = build_temporary_forge_trust_policy(
        current_policy,
        lambda_role_arn,
    )

    update_assume_role_policy(role_name, temporary_policy)
    updated_policy = wait_for_temporary_forge_role_trust(
        role_name,
        lambda_role_arn,
    )
    log_trust_policy(role_name, 'after update', updated_policy)
    LOG.info(
        'Temporary trust statement added for Forge role: %s',
        forge_role_arn,
    )


def remove_temporary_forge_role_trust(role_name: str) -> bool:
    LOG.info(
        'Removing temporary Forge trust policy statement for role: %s',
        role_name,
    )
    current_policy = get_role_assume_policy(role_name)
    if not policy_has_validator_statement(current_policy):
        LOG.info(
            'Temporary trust statement was already absent for Forge role: %s',
            role_name,
        )
        return False

    log_trust_policy(role_name, 'before cleanup', current_policy)
    cleaned_policy = remove_validator_trust_statement(current_policy)
    update_assume_role_policy(role_name, cleaned_policy)
    log_trust_policy(
        role_name,
        'after cleanup',
        get_role_assume_policy(role_name),
    )
    LOG.info(
        'Removed temporary Forge trust policy statement for role: %s',
        role_name,
    )
    return True


def remove_temporary_forge_role_trust_by_arn(
    forge_role_arn: str,
) -> Dict[str, Any]:
    role_name = get_forge_role_name(forge_role_arn)
    cleanup_result: Dict[str, Any] = {
        'forge_role_arn': forge_role_arn,
        'temporary_trust_policy_removed': False,
        'cleanup_error': None,
    }

    try:
        cleanup_result[
            'temporary_trust_policy_removed'
        ] = remove_temporary_forge_role_trust(role_name)
    except Exception as e:
        LOG.error(
            'Failed to remove temporary trust policy for Forge role %s: %s',
            forge_role_arn,
            e,
        )
        cleanup_result['cleanup_error'] = str(e)

    return cleanup_result


def cleanup_forge_roles(forge_role_arns: List[str]) -> List[Dict[str, Any]]:
    cleanup_results: List[Dict[str, Any]] = []
    for forge_role_arn in forge_role_arns:
        cleanup_results.append(
            remove_temporary_forge_role_trust_by_arn(forge_role_arn),
        )

    return cleanup_results


def build_session_policy_for_tenants(tenant_role_arns: List[str]) -> str:
    """
    Restrictive inline session policy: only allow sts:AssumeRole on tenant
    roles.
    This means the forge-role session can't do anything else.
    """
    policy = {
        'Version': '2012-10-17',
        'Statement': [
            {
                'Sid': 'AllowAssumeTenantRolesForValidation',
                'Effect': 'Allow',
                'Action': [
                    'sts:AssumeRole',
                    'sts:TagSession',
                ],
                'Resource': tenant_role_arns,
            }
        ],
    }
    return json.dumps(policy)


def assume_role(
    role_arn: str,
    session_name: str,
    session_policy: str | None = None,
    retry_access_denied: bool = False,
) -> Dict[str, Any]:
    """
    Wrapper around sts.assume_role that optionally applies a restrictive
    session policy.
    """
    LOG.info(
        'Attempting to assume role: %s (Session: %s)',
        role_arn,
        session_name,
    )
    kwargs: Dict[str, Any] = {
        'RoleArn': role_arn,
        'RoleSessionName': session_name,
        'DurationSeconds': 900,
    }
    if session_policy:
        kwargs['Policy'] = session_policy

    return call_with_backoff(
        operation_name=f'assume role {role_arn}',
        operation=lambda: sts.assume_role(**kwargs),
        max_attempts=FORGE_ASSUME_MAX_ATTEMPTS,
        retry_access_denied=retry_access_denied,
    )


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


def get_lambda_caller_identity() -> Dict[str, Any]:
    identity = sts.get_caller_identity()
    LOG.info(
        'Lambda caller identity: Account=%s Arn=%s UserId=%s',
        identity.get('Account'),
        identity.get('Arn'),
        identity.get('UserId'),
    )
    return identity
