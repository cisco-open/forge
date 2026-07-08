from __future__ import annotations

import importlib.util
import json
from pathlib import Path
from types import ModuleType

import pytest
from botocore.exceptions import ClientError
from conftest import requires_aws

pytestmark = [pytest.mark.mutation, requires_aws]

SOURCE = Path(__file__).resolve().parents[2].joinpath(
    'modules/platform/forge_runners/redrive_deadletter/lambda/'
    'redrive_deadletter.py',
)

MUTANTS = {
    'uses_main_queue_as_redrive_source': [
        (
            "dlq_identifier = entry['dlq']",
            "dlq_identifier = entry['main']",
        ),
    ],
    'reports_client_error_as_started': [
        (
            "'status': 'error',",
            "'status': 'started',",
        ),
    ],
}


class FakeSqs:
    def __init__(self, *, fail: bool = False) -> None:
        self.fail = fail
        self.calls: list[dict] = []

    def start_message_move_task(self, **kwargs):
        self.calls.append(kwargs)
        if self.fail:
            raise ClientError({
                'Error': {
                    'Code': 'AccessDenied',
                    'Message': 'not authorized',
                },
            }, 'StartMessageMoveTask')
        return {'TaskHandle': 'task-123'}


def load_mutant(tmp_path: Path, source: str) -> ModuleType:
    mutant_path = tmp_path / 'redrive_deadletter.py'
    mutant_path.write_text(source, encoding='utf-8')

    spec = importlib.util.spec_from_file_location(
        'redrive_deadletter_mutant',
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


@pytest.mark.parametrize('mutant_name', sorted(MUTANTS))
def test_redrive_deadletter_mutants_are_observable(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    mutant_name: str,
) -> None:
    module = load_mutant(tmp_path, mutated_source(mutant_name))

    if mutant_name == 'uses_main_queue_as_redrive_source':
        fake_sqs = FakeSqs()
        module.sqs = fake_sqs
        monkeypatch.setenv('SQS_MAP', json.dumps({
            'jobs': {
                'main': 'arn:aws:sqs:us-west-2:123456789012:main',
                'dlq': 'arn:aws:sqs:us-west-2:123456789012:dlq',
            },
        }))

        result = module.lambda_handler({}, None)

        assert result['status'] == 'ok'
        assert fake_sqs.calls == [{
            'SourceArn': 'arn:aws:sqs:us-west-2:123456789012:main',
        }]
        return

    if mutant_name == 'reports_client_error_as_started':
        result = module.start_dlq_redrive_to_source(
            FakeSqs(fail=True),
            'arn:aws:sqs:us-west-2:123456789012:dlq',
        )

        assert result['status'] == 'started'
        assert 'AccessDenied' in result['error']
        return

    raise AssertionError(f'Unhandled mutant: {mutant_name}')
