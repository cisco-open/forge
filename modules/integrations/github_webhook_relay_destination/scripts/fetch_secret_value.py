#!/usr/bin/env python3
"""Fetch a cross-account secret through the configured two-hop role chain."""

from __future__ import annotations

import json
import os
import subprocess
import sys
from collections.abc import Mapping, Sequence


class SecretFetchError(RuntimeError):
    """Raised when the role chain or secret lookup cannot be completed."""


def run_aws(
    arguments: Sequence[str],
    *,
    environment: Mapping[str, str],
) -> str:
    """Run an AWS CLI command and return its standard output."""
    try:
        result = subprocess.run(
            ['aws', *arguments],
            check=True,
            capture_output=True,
            text=True,
            env=dict(environment),
        )
    except FileNotFoundError as error:
        raise SecretFetchError('AWS CLI executable was not found') from error
    except OSError as error:
        raise SecretFetchError(f'Unable to run AWS CLI: {error}') from error
    except subprocess.CalledProcessError as error:
        detail = (error.stderr or '').strip()
        if not detail:
            detail = f'AWS CLI exited with status {error.returncode}'
        raise SecretFetchError(f'AWS CLI command failed: {detail}') from error

    return result.stdout


def assume_role(
    role_arn: str,
    session_name: str,
    region: str,
    *,
    environment: Mapping[str, str],
    profile: str | None = None,
) -> dict[str, str]:
    """Assume one role and return the three temporary credential values."""
    arguments = [
        'sts',
        'assume-role',
        '--role-arn',
        role_arn,
        '--role-session-name',
        session_name,
    ]
    if profile:
        arguments.extend(['--profile', profile])
    arguments.extend(
        [
            '--region',
            region,
            '--query',
            'Credentials',
            '--output',
            'json',
        ]
    )

    raw_credentials = run_aws(arguments, environment=environment)
    try:
        credentials = json.loads(raw_credentials)
    except json.JSONDecodeError as error:
        raise SecretFetchError(
            'AWS CLI assume-role returned invalid credentials'
        ) from error

    if not isinstance(credentials, dict):
        raise SecretFetchError(
            'AWS CLI assume-role returned invalid credentials'
        )

    required_keys = ('AccessKeyId', 'SecretAccessKey', 'SessionToken')
    if not all(
        isinstance(credentials.get(key), str) and credentials[key]
        for key in required_keys
    ):
        raise SecretFetchError(
            'AWS CLI assume-role returned invalid credentials'
        )
    return {key: credentials[key] for key in required_keys}


def credential_environment(
    base_environment: Mapping[str, str],
    credentials: Mapping[str, str],
) -> dict[str, str]:
    """Build an AWS CLI environment for the next role-chain hop."""
    environment = dict(base_environment)
    environment.pop('AWS_PROFILE', None)
    environment.pop('AWS_DEFAULT_PROFILE', None)
    environment.update(
        {
            'AWS_ACCESS_KEY_ID': credentials['AccessKeyId'],
            'AWS_SECRET_ACCESS_KEY': credentials['SecretAccessKey'],
            'AWS_SESSION_TOKEN': credentials['SessionToken'],
        }
    )
    return environment


def fetch_secret_value(
    reader_role_arn: str,
    source_role_arn: str,
    source_secret_arn: str,
    source_secret_region: str,
    aws_profile: str,
    aws_region: str,
    *,
    environment: Mapping[str, str] | None = None,
) -> str:
    """Assume the reader and source roles, then return the secret string."""
    base_environment = dict(
        os.environ if environment is None else environment
    )
    base_environment['AWS_PAGER'] = ''
    reader_credentials = assume_role(
        reader_role_arn,
        'reader-temp',
        aws_region,
        environment=base_environment,
        profile=aws_profile,
    )
    reader_environment = credential_environment(
        base_environment,
        reader_credentials,
    )

    source_credentials = assume_role(
        source_role_arn,
        'source-temp',
        aws_region,
        environment=reader_environment,
    )
    source_environment = credential_environment(
        base_environment,
        source_credentials,
    )

    secret_value = run_aws(
        [
            'secretsmanager',
            'get-secret-value',
            '--secret-id',
            source_secret_arn,
            '--region',
            source_secret_region,
            '--query',
            'SecretString',
            '--output',
            'text',
        ],
        environment=source_environment,
    )
    return secret_value.rstrip('\r\n')


def main(arguments: Sequence[str] | None = None) -> int:
    """Run the Terraform external-data helper."""
    resolved_arguments = list(
        sys.argv[1:] if arguments is None else arguments
    )
    if len(resolved_arguments) != 6:
        print(
            'Usage: fetch_secret_value.py READER_ROLE_ARN SOURCE_ROLE_ARN '
            'SOURCE_SECRET_ARN SOURCE_SECRET_REGION AWS_PROFILE AWS_REGION',
            file=sys.stderr,
        )
        return 2

    try:
        secret_value = fetch_secret_value(*resolved_arguments)
    except SecretFetchError as error:
        print(str(error), file=sys.stderr)
        return 1

    json.dump(
        {'secret_value': secret_value},
        sys.stdout,
        separators=(',', ':'),
    )
    sys.stdout.write('\n')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
