from __future__ import annotations

import importlib.util
import json
from pathlib import Path
from types import ModuleType

import pytest
from conftest import requires_aws

pytestmark = [pytest.mark.mutation, requires_aws]

SOURCE = Path(__file__).resolve().parents[2].joinpath(
    'modules/integrations/splunk_stuck_workflow_job_dispatcher/lambda/'
    'handler.py',
)

MUTANTS = {
    'accepts_missing_required_splunk_fields': [
        (
            'if missing:',
            'if False:',
        ),
    ],
    'omits_tenant_region_from_dedupe_key': [
        (
            'return f"{tenant}#{aws_region}#{repository}#{payload[\'workflow_job_id\']}"',
            'return f"{repository}#{payload[\'workflow_job_id\']}"',
        ),
    ],
    'accepts_wrong_webhook_token': [
        (
            'if not secrets.compare_digest(expected_token, provided_token):',
            'if False:',
        ),
    ],
}


def load_mutant(tmp_path: Path, source: str) -> ModuleType:
    mutant_path = tmp_path / 'handler.py'
    mutant_path.write_text(source, encoding='utf-8')

    spec = importlib.util.spec_from_file_location(
        'splunk_stuck_dispatcher_mutant',
        mutant_path,
    )
    assert spec is not None
    assert spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def mutated_source(name: str) -> str:
    source = SOURCE.read_text(encoding='utf-8')
    for old, new in MUTANTS[name]:
        assert old in source
        source = source.replace(old, new, 1)
    return source


def apigw_event(*, token: str) -> dict:
    return {
        'pathParameters': {'token': token},
        'headers': {'content-type': 'application/json'},
        'body': json.dumps({'results': []}),
        'isBase64Encoded': False,
        'requestContext': {
            'http': {'method': 'POST', 'path': '/splunk/test'},
        },
    }


@pytest.mark.parametrize('mutant_name', sorted(MUTANTS))
def test_splunk_stuck_dispatcher_mutants_are_observable(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    mutant_name: str,
) -> None:
    module = load_mutant(tmp_path, mutated_source(mutant_name))

    if mutant_name == 'accepts_missing_required_splunk_fields':
        normalized = module.normalize_result({
            'workflowJobId': 42,
            'forgecicd_tenant': 'acgw',
            'aws_region': 'us-west-2',
            'github_delivery': '123456',
        })

        assert normalized['queued_url'] is None
        return

    if mutant_name == 'omits_tenant_region_from_dedupe_key':
        alpha_key = module.dedupe_key({
            'tenant': 'alpha',
            'aws_region': 'us-west-2',
            'repository': 'acme/app',
            'workflow_job_id': 42,
        })
        bravo_key = module.dedupe_key({
            'tenant': 'bravo',
            'aws_region': 'eu-west-1',
            'repository': 'acme/app',
            'workflow_job_id': 42,
        })

        assert alpha_key == bravo_key == 'acme/app#42'
        return

    if mutant_name == 'accepts_wrong_webhook_token':
        monkeypatch.setenv('WEBHOOK_TOKEN', 'expected-token')
        monkeypatch.setenv('DEDUPE_TABLE', 'not-used-for-empty-results')

        response = module.lambda_handler(
            apigw_event(token='wrong-token'), None)

        assert response['statusCode'] == 200
        assert json.loads(response['body']) == {
            'message': 'No results to dispatch',
        }
        return

    raise AssertionError(f'Unhandled mutant: {mutant_name}')
