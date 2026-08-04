"""Create, read, and delete Splunk Data Manager inputs."""

from __future__ import annotations

import copy
import hashlib
import json
import time
from collections.abc import Callable

from .client import SplunkWebClient
from .input_state import (input_uses_s3, s3_input_matches_request,
                          validate_input_document, wait_for_input)
from .runtime import (ArtifactPaths, JsonObject, Logger, RuntimeConfig,
                      SplunkHttpError, SplunkIntegrationError, atomic_write,
                      encode_json)

NOAH_TOKEN_PENDING = 'Noah stack token creation in progress'

DATASET_HEC_CATEGORIES = {
    'cwl-api-gateway': 'aws-cwl',
    'cwl-cloudhsm': 'aws-cwl',
    'cwl-documentDB': 'aws-cwl',
    'cwl-eks': 'aws-cwl',
    'cwl-lambda': 'aws-cwl',
    'cwl-rds': 'aws-cwl',
    'cwl-custom-logs': 'cwl-custom-logs',
    'cwl-vpc-flow-logs': 'cwl-vpc-flow-logs',
    'cloudtrail': 'cloudtrail',
    'securityhub': 'securityhub',
    'guardduty': 'guardduty',
    'iam-aa': 'iam-aa',
    'iam-cr': 'iam-cr',
    'metadata': 'metadata',
}

PUSH_HEC_CLEANUP_CATEGORIES = (
    'aws-cwl',
    'cwl-custom-logs',
    'cwl-vpc-flow-logs',
    'cloudtrail',
    'securityhub',
    'guardduty',
    'iam-aa',
    'iam-cr',
    'metadata',
)

TOP_LEVEL_RESPONSE_FIELDS = (
    '_key',
    '_user',
    'createTime',
    'dataSourcesStatus',
    'id',
    'lastUpdateTime',
    'schemaVersion',
)

DETAIL_RESPONSE_FIELDS = (
    'stackName',
    'version',
    'resources',
    'resourceTags',
)


def validate_cloudformation_template(raw_template: bytes) -> bool:
    """Require a JSON CloudFormation template with non-empty Resources."""
    try:
        template = json.loads(raw_template)
    except (UnicodeDecodeError, json.JSONDecodeError):
        return False
    if not isinstance(template, dict):
        return False
    resources = template.get('Resources')
    return isinstance(resources, dict) and bool(resources)


def dataset_hec_categories(
    document: JsonObject,
) -> list[tuple[str, str]]:
    """Map dataset names to the established push-input HEC categories."""
    if not validate_input_document(document):
        raise SplunkIntegrationError(
            'Cannot map HEC categories from an invalid input'
        )
    categories = []
    for dataset in sorted(document['details']['datasetInfo']):
        category = DATASET_HEC_CATEGORIES.get(dataset)
        if category is not None:
            categories.append((dataset, category))
    return categories


def ensure_hec_tokens(
    client: SplunkWebClient,
    document: JsonObject,
    *,
    initial_delay_seconds: int,
    sleep: Callable[[float], None] = time.sleep,
    logger: Logger | None = None,
) -> None:
    """Wait for all push-input HEC tokens; S3 inputs have none."""
    log = logger or (lambda _message: None)
    categories = dataset_hec_categories(document)
    if categories and initial_delay_seconds:
        sleep(initial_delay_seconds)

    for dataset, category in categories:
        while True:
            token_response = client.get_hec_token(category)
            if token_response.get('details') == NOAH_TOKEN_PENDING:
                log(
                    'HEC token creation is still in progress for '
                    f'dataset {category}.'
                )
                sleep(60)
                continue
            if token_response.get('token'):
                log(f'HEC token exists for dataset {category}.')
                break
            log(
                'Skipping unexpected HEC token response for '
                f'dataset {dataset}.'
            )
            break


def build_delete_payload(
    document: JsonObject,
    *,
    mode: str = 'MarkedForDelete',
) -> JsonObject:
    """Remove response-owned fields before updating deletion mode."""
    payload = copy.deepcopy(document)
    payload['mode'] = mode
    for field_name in TOP_LEVEL_RESPONSE_FIELDS:
        payload.pop(field_name, None)
    details = payload.get('details')
    if not isinstance(details, dict):
        raise SplunkIntegrationError(
            'Cannot delete an input without a details object'
        )
    for field_name in DETAIL_RESPONSE_FIELDS:
        details.pop(field_name, None)
    return payload


def create_integration(
    client: SplunkWebClient,
    config: RuntimeConfig,
    paths: ArtifactPaths,
    *,
    sleep: Callable[[float], None] = time.sleep,
    logger: Logger | None = None,
) -> None:
    """Create or update an input and write its template artifact."""
    log = logger or (lambda _message: None)
    request = _required_request(config)
    put_response = client.put_input(request)

    expected_version = None
    expected_update_time = None
    if input_uses_s3(request):
        if put_response is None or not s3_input_matches_request(
            put_response,
            request,
        ):
            raise SplunkIntegrationError(
                'Splunk returned an invalid S3 data input update response'
            )
        version = put_response['details'].get('version')
        update_time = put_response.get('lastUpdateTime')
        if version is None or not update_time:
            raise SplunkIntegrationError(
                'Splunk did not return a version and update time for '
                'the S3 data input update'
            )
        expected_version = str(version)
        expected_update_time = str(update_time)

    input_document = wait_for_input(
        client.get_input,
        request=request,
        expected_version=expected_version,
        expected_update_time=expected_update_time,
        sleep=sleep,
    )
    atomic_write(paths.input_json, encode_json(input_document))
    ensure_hec_tokens(
        client,
        input_document,
        initial_delay_seconds=300,
        sleep=sleep,
        logger=log,
    )
    _write_template(client, paths)


def get_integration(
    client: SplunkWebClient,
    config: RuntimeConfig,
    paths: ArtifactPaths,
    *,
    sleep: Callable[[float], None] = time.sleep,
    logger: Logger | None = None,
) -> dict[str, str]:
    """Refresh an input and return the external-provider result."""
    request = _required_request(config)
    input_document = wait_for_input(
        client.get_input,
        request=request,
        sleep=sleep,
    )
    atomic_write(paths.input_json, encode_json(input_document))
    ensure_hec_tokens(
        client,
        input_document,
        initial_delay_seconds=0,
        sleep=sleep,
        logger=logger,
    )
    raw_template = _write_template(client, paths)

    details = input_document['details']
    version = details.get('version')
    stack_name = details.get('stackName')
    if version is None or not isinstance(stack_name, str) or not stack_name:
        raise SplunkIntegrationError(
            'Splunk input response is missing version or stackName'
        )
    return {
        'version': str(version),
        'template_hash': hashlib.sha256(raw_template).hexdigest(),
        'stack_name': stack_name,
    }


def delete_integration(
    client: SplunkWebClient,
    paths: ArtifactPaths,
    *,
    logger: Logger | None = None,
) -> None:
    """Delete an input while preserving push-input HEC cleanup."""
    log = logger or (lambda _message: None)
    try:
        input_document = client.get_input()
    except SplunkHttpError as error:
        if error.status == 404:
            log('Splunk input is already absent; deletion is complete.')
            return
        raise

    atomic_write(paths.input_json, encode_json(input_document))
    client.check_delete_readiness()
    client.put_input(build_delete_payload(input_document))
    client.check_delete_readiness()

    if not input_uses_s3(input_document):
        for category in PUSH_HEC_CLEANUP_CATEGORIES:
            client.delete_hec_token(category)

    client.check_delete_readiness()
    client.delete_input()


def _write_template(
    client: SplunkWebClient,
    paths: ArtifactPaths,
) -> bytes:
    raw_template = client.get_template()
    if not validate_cloudformation_template(raw_template):
        raise SplunkIntegrationError(
            'Splunk returned an invalid CloudFormation template'
        )
    atomic_write(paths.template_json, raw_template)
    return raw_template


def _required_request(config: RuntimeConfig) -> JsonObject:
    if config.input_request is None:
        raise SplunkIntegrationError(
            'The operation requires a Splunk input request'
        )
    if not validate_input_document(config.input_request):
        raise SplunkIntegrationError(
            'The configured Splunk data input request is invalid'
        )
    return config.input_request
