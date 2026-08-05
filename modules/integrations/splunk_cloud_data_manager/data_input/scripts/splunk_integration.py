#!/usr/bin/env python3
"""Terraform command for Splunk Data Manager lifecycle operations."""

from __future__ import annotations

import argparse
import json
import os
import sys
from collections.abc import Mapping, Sequence
from pathlib import Path

from splunk_api import RuntimeConfig, SplunkIntegrationError, SplunkWebClient
from splunk_lifecycle import (ArtifactPaths, FileLogger, create_integration,
                              delete_integration, get_integration)


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


def _build_runtime(
    config: RuntimeConfig,
    artifact_dir: Path,
) -> tuple[SplunkWebClient, ArtifactPaths, FileLogger]:
    paths = ArtifactPaths.for_input(
        config.input_id,
        artifact_dir=artifact_dir,
    )
    logger = FileLogger(paths.log)
    client = SplunkWebClient(config, logger=logger)
    return client, paths, logger


def handle_create(
    environment: Mapping[str, str],
    artifact_dir: Path,
) -> None:
    """Create or update one input from Terraform environment values."""
    config = config_from_mapping(environment, require_request=True)
    client, paths, logger = _build_runtime(config, artifact_dir)
    try:
        client.login()
        create_integration(client, config, paths, logger=logger)
    except Exception as error:
        logger(f'Splunk Data Manager create failed: {error}')
        raise


def handle_get(
    input_stream,
    output_stream,
    artifact_dir: Path,
) -> None:
    """Refresh one input from an external-provider query."""
    query = json.load(input_stream)
    if not isinstance(query, dict):
        raise SplunkIntegrationError(
            'The external-provider query must be a JSON object'
        )
    config = config_from_mapping(query, require_request=True)
    client, paths, logger = _build_runtime(config, artifact_dir)
    try:
        client.login()
        result = get_integration(client, config, paths, logger=logger)
        print(
            json.dumps(result, separators=(',', ':')),
            file=output_stream,
            flush=True,
        )
    except Exception as error:
        logger(f'Splunk Data Manager get failed: {error}')
        raise


def handle_delete(
    environment: Mapping[str, str],
    artifact_dir: Path,
) -> None:
    """Delete one input from Terraform environment values."""
    config = config_from_mapping(environment, require_request=False)
    client, paths, logger = _build_runtime(config, artifact_dir)
    try:
        client.login()
        delete_integration(client, paths, logger=logger)
    except Exception as error:
        logger(f'Splunk Data Manager delete failed: {error}')
        raise


def _parse_operation(argv: Sequence[str] | None) -> str:
    parser = argparse.ArgumentParser(
        description='Manage a Splunk Cloud Data Manager input.'
    )
    parser.add_argument('operation', choices=('create', 'get', 'delete'))
    return parser.parse_args(argv).operation


def main(
    argv: Sequence[str] | None = None,
    *,
    environ: Mapping[str, str] | None = None,
    input_stream=None,
    output_stream=None,
    error_stream=None,
    artifact_dir: Path = Path('/tmp'),
) -> int:
    """Dispatch one Terraform-facing lifecycle command."""
    operation = _parse_operation(argv)
    environment = os.environ if environ is None else environ
    standard_input = sys.stdin if input_stream is None else input_stream
    standard_output = sys.stdout if output_stream is None else output_stream
    standard_error = sys.stderr if error_stream is None else error_stream

    try:
        if operation == 'create':
            handle_create(environment, artifact_dir)
        elif operation == 'get':
            handle_get(standard_input, standard_output, artifact_dir)
        else:
            handle_delete(environment, artifact_dir)
        return 0
    except Exception as error:
        print(
            f'Splunk Data Manager {operation} failed: {error}',
            file=standard_error,
        )
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
