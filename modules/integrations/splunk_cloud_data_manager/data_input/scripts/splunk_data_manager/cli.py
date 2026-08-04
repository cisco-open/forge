"""Command-line orchestration for Terraform lifecycle operations."""

from __future__ import annotations

import argparse
import json
import os
import sys
from collections.abc import Mapping, Sequence
from pathlib import Path

from .client import SplunkWebClient
from .lifecycle import create_integration, delete_integration, get_integration
from .runtime import (ArtifactPaths, FileLogger, RuntimeConfig,
                      SplunkIntegrationError)


def config_from_mapping(
    values: Mapping[str, str],
    *,
    require_request: bool,
) -> RuntimeConfig:
    """Parse Terraform environment or external-query values."""
    def required(name: str) -> str:
        value = values.get(name)
        if not isinstance(value, str) or not value:
            raise SplunkIntegrationError(
                f'Required runtime value {name} is missing'
            )
        return value

    input_request = None
    if require_request:
        raw_request = required('SPLUNK_CLOUD_INPUT_JSON')
        try:
            decoded_request = json.loads(raw_request)
        except json.JSONDecodeError as error:
            raise SplunkIntegrationError(
                'SPLUNK_CLOUD_INPUT_JSON is not valid JSON'
            ) from error
        if not isinstance(decoded_request, dict):
            raise SplunkIntegrationError(
                'SPLUNK_CLOUD_INPUT_JSON must contain a JSON object'
            )
        input_request = decoded_request

    return RuntimeConfig(
        cloud_url=required('SPLUNK_CLOUD'),
        input_id=required('SPLUNK_INPUT_UUID'),
        username=required('SPLUNK_CLOUD_USERNAME'),
        password=required('SPLUNK_CLOUD_PASSWORD'),
        input_request=input_request,
    )


def main(
    argv: Sequence[str] | None = None,
    *,
    environ: Mapping[str, str] | None = None,
    input_stream=None,
    output_stream=None,
    error_stream=None,
    artifact_dir: Path = Path('/tmp'),
) -> int:
    """Run one Terraform-facing lifecycle subcommand."""
    parser = argparse.ArgumentParser(
        description='Manage a Splunk Cloud Data Manager input.'
    )
    parser.add_argument('operation', choices=('create', 'get', 'delete'))
    arguments = parser.parse_args(argv)

    standard_input = sys.stdin if input_stream is None else input_stream
    standard_output = sys.stdout if output_stream is None else output_stream
    standard_error = sys.stderr if error_stream is None else error_stream
    logger = None

    try:
        if arguments.operation == 'get':
            query = json.load(standard_input)
            if not isinstance(query, dict):
                raise SplunkIntegrationError(
                    'The external-provider query must be a JSON object'
                )
            config = config_from_mapping(query, require_request=True)
        else:
            environment = os.environ if environ is None else environ
            config = config_from_mapping(
                environment,
                require_request=arguments.operation == 'create',
            )

        paths = ArtifactPaths.for_input(
            config.input_id,
            artifact_dir=artifact_dir,
        )
        logger = FileLogger(paths.log)
        client = SplunkWebClient(config, logger=logger)
        client.login()

        if arguments.operation == 'create':
            create_integration(client, config, paths, logger=logger)
        elif arguments.operation == 'get':
            result = get_integration(client, config, paths, logger=logger)
            print(
                json.dumps(result, separators=(',', ':')),
                file=standard_output,
                flush=True,
            )
        else:
            delete_integration(client, paths, logger=logger)
        return 0
    except Exception as error:
        if logger is not None:
            logger(
                f'Splunk Data Manager {arguments.operation} failed: {error}'
            )
        print(
            f'Splunk Data Manager {arguments.operation} failed: {error}',
            file=standard_error,
        )
        return 1
