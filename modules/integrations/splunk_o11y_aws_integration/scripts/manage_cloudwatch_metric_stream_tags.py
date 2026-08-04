#!/usr/bin/env python3
"""Manage tags on the Splunk-created CloudWatch Metric Stream."""

from __future__ import annotations

import os
import subprocess
import sys
import time
from collections.abc import Callable, Mapping, Sequence
from dataclasses import dataclass
from typing import TextIO

MAX_ATTEMPTS = 60
RETRY_SECONDS = 15

CommandRunner = Callable[..., subprocess.CompletedProcess[str]]
Sleeper = Callable[[float], None]


class MetricStreamTagError(RuntimeError):
    """Raised when Metric Stream tag management cannot continue."""

    def __init__(self, message: str, *, exit_code: int = 1):
        super().__init__(message)
        self.exit_code = exit_code


@dataclass(frozen=True, slots=True)
class RuntimeConfig:
    """Runtime values supplied by the Terraform provisioner."""

    region: str
    stream_name_prefix: str
    tag_count: int
    tags_json: str | None = None
    tag_keys_json: str | None = None


def config_from_mapping(
    values: Mapping[str, str],
    *,
    operation: str,
) -> RuntimeConfig:
    """Read and validate the Terraform provisioner's environment."""

    def required(name: str) -> str:
        value = values.get(name)
        if not isinstance(value, str) or not value:
            raise MetricStreamTagError(f'{name} must be set')
        return value

    region = required('AWS_REGION')
    stream_name_prefix = required('STREAM_NAME_PREFIX')
    raw_tag_count = required('TAG_COUNT')
    try:
        tag_count = int(raw_tag_count)
    except ValueError as error:
        raise MetricStreamTagError('TAG_COUNT must be an integer') from error

    tags_json = values.get('TAGS_JSON')
    tag_keys_json = values.get('TAG_KEYS_JSON')
    if tag_count != 0:
        if operation == 'apply' and not tags_json:
            raise MetricStreamTagError(
                'TAGS_JSON must be set when applying tags'
            )
        if operation == 'remove' and not tag_keys_json:
            raise MetricStreamTagError(
                'TAG_KEYS_JSON must be set when removing tags'
            )

    return RuntimeConfig(
        region=region,
        stream_name_prefix=stream_name_prefix,
        tag_count=tag_count,
        tags_json=tags_json,
        tag_keys_json=tag_keys_json,
    )


def resolve_metric_stream_arn(
    config: RuntimeConfig,
    *,
    runner: CommandRunner = subprocess.run,
) -> str | None:
    """Return the one matching Metric Stream ARN, if it exists."""
    command = [
        'aws',
        'cloudwatch',
        'list-metric-streams',
        '--region',
        config.region,
        '--query',
        (
            'Entries[?starts_with(Name, '
            f"'{config.stream_name_prefix}')].Arn"
        ),
        '--output',
        'text',
    ]
    try:
        result = runner(
            command,
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
    except OSError as error:
        raise MetricStreamTagError(str(error), exit_code=2) from error

    if result.returncode != 0:
        message = (result.stderr or '').strip()
        if not message:
            message = 'Failed to list CloudWatch Metric Streams'
        raise MetricStreamTagError(message, exit_code=2)

    matching_arns = [
        candidate
        for candidate in (result.stdout or '').replace('\t', '\n').splitlines()
        if candidate and candidate != 'None'
    ]
    if not matching_arns:
        return None
    if len(matching_arns) != 1:
        formatted_arns = ''.join(f'\n  {arn}' for arn in matching_arns)
        raise MetricStreamTagError(
            'Expected exactly one CloudWatch Metric Stream with prefix '
            f"'{config.stream_name_prefix}'; found {len(matching_arns)}."
            f'{formatted_arns}',
            exit_code=2,
        )
    return matching_arns[0]


def _run_tag_command(
    command: list[str],
    *,
    runner: CommandRunner,
) -> tuple[bool, str]:
    """Run a tag operation and identify a resource-not-found race."""
    try:
        result = runner(
            command,
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )
    except OSError as error:
        raise MetricStreamTagError(str(error)) from error

    if result.returncode == 0:
        return True, ''

    output = (result.stdout or '').strip()
    if 'ResourceNotFoundException' in output:
        return False, output
    raise MetricStreamTagError(output or 'CloudWatch tag operation failed')


def apply_tags(
    config: RuntimeConfig,
    *,
    runner: CommandRunner = subprocess.run,
    sleep: Sleeper = time.sleep,
    output_stream: TextIO = sys.stdout,
) -> None:
    """Apply all configured tags, retrying Metric Stream creation races."""
    if config.tag_count == 0:
        print('No CloudWatch Metric Stream tags to apply.', file=output_stream)
        return

    for attempt in range(1, MAX_ATTEMPTS + 1):
        resource_arn = resolve_metric_stream_arn(config, runner=runner)
        if resource_arn is not None:
            print(
                f'Applying {config.tag_count} tag(s) to '
                f'CloudWatch Metric Stream: {resource_arn}',
                file=output_stream,
            )
            tagged, _output = _run_tag_command(
                [
                    'aws',
                    'cloudwatch',
                    'tag-resource',
                    '--region',
                    config.region,
                    '--resource-arn',
                    resource_arn,
                    '--tags',
                    config.tags_json or '',
                ],
                runner=runner,
            )
            if tagged:
                return

        if attempt == MAX_ATTEMPTS:
            raise MetricStreamTagError(
                'CloudWatch Metric Stream with prefix '
                f"'{config.stream_name_prefix}' was not available after "
                f'{MAX_ATTEMPTS} attempts.'
            )

        print(
            'CloudWatch Metric Stream with prefix '
            f"'{config.stream_name_prefix}' is not available yet; "
            f'retrying in {RETRY_SECONDS} seconds.',
            file=output_stream,
        )
        sleep(RETRY_SECONDS)


def remove_tags(
    config: RuntimeConfig,
    *,
    runner: CommandRunner = subprocess.run,
    output_stream: TextIO = sys.stdout,
) -> None:
    """Remove all keys managed by the previous Terraform resource."""
    if config.tag_count == 0:
        print('No CloudWatch Metric Stream tags to remove.', file=output_stream)
        return

    resource_arn = resolve_metric_stream_arn(config, runner=runner)
    if resource_arn is None:
        print(
            'CloudWatch Metric Stream no longer exists; '
            'no tags remain to remove.',
            file=output_stream,
        )
        return

    print(
        'Removing previously managed tags from CloudWatch Metric Stream: '
        f'{resource_arn}',
        file=output_stream,
    )
    removed, _output = _run_tag_command(
        [
            'aws',
            'cloudwatch',
            'untag-resource',
            '--region',
            config.region,
            '--resource-arn',
            resource_arn,
            '--tag-keys',
            config.tag_keys_json or '',
        ],
        runner=runner,
    )
    if not removed:
        print(
            'CloudWatch Metric Stream no longer exists; '
            'no tags remain to remove.',
            file=output_stream,
        )


def main(
    argv: Sequence[str] | None = None,
    *,
    environ: Mapping[str, str] | None = None,
    runner: CommandRunner = subprocess.run,
    sleep: Sleeper = time.sleep,
    output_stream: TextIO = sys.stdout,
    error_stream: TextIO = sys.stderr,
) -> int:
    """Run one Terraform-facing Metric Stream tag operation."""
    arguments = list(sys.argv[1:] if argv is None else argv)
    if len(arguments) != 1 or arguments[0] not in {'apply', 'remove'}:
        print(f'Usage: {sys.argv[0]} apply|remove', file=error_stream)
        return 2

    operation = arguments[0]
    environment = os.environ if environ is None else environ
    try:
        config = config_from_mapping(environment, operation=operation)
        if operation == 'apply':
            apply_tags(
                config,
                runner=runner,
                sleep=sleep,
                output_stream=output_stream,
            )
        else:
            remove_tags(
                config,
                runner=runner,
                output_stream=output_stream,
            )
        return 0
    except MetricStreamTagError as error:
        print(error, file=error_stream)
        return error.exit_code


if __name__ == '__main__':
    raise SystemExit(main())
