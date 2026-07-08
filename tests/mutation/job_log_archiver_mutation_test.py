from __future__ import annotations

import importlib.util
from pathlib import Path
from types import ModuleType

import pytest
from conftest import requires_aws

pytestmark = [pytest.mark.mutation, requires_aws]

SOURCE = Path(__file__).resolve().parents[2].joinpath(
    'modules/platform/forge_runners/github_actions_job_logs/lambda/'
    'job_log_archiver/job_log_archiver.py',
)

MUTANTS = {
    'swallows_archiver_exceptions': [
        (
            '        LOG.exception(\n'
            "            'Unhandled exception in job_log_archiver lambda. Error: %s', str(e))\n"
            '        raise',
            '        LOG.exception(\n'
            "            'Unhandled exception in job_log_archiver lambda. Error: %s', str(e))\n"
            '        return None',
        ),
    ],
    'ignores_metadata_field_limit': [
        (
            'if len(fields) >= MAX_METADATA_FIELDS:\n'
            '        return fields',
            'if False:\n'
            '        return fields',
        ),
        (
            'if value is None or len(fields) >= MAX_METADATA_FIELDS:',
            'if value is None:',
        ),
        (
            'if len(fields) >= MAX_METADATA_FIELDS:\n'
            '                break',
            'if False:\n'
            '                break',
        ),
        (
            'if len(fields) >= MAX_METADATA_FIELDS:\n'
            '                break',
            'if False:\n'
            '                break',
        ),
    ],
    'does_not_truncate_metadata_values': [
        (
            'fields[name] = value[:MAX_METADATA_VALUE_LENGTH]',
            'fields[name] = value',
        ),
    ],
}


def load_mutant(tmp_path: Path, source: str) -> ModuleType:
    mutant_path = tmp_path / 'job_log_archiver.py'
    mutant_path.write_text(source, encoding='utf-8')

    spec = importlib.util.spec_from_file_location(
        'job_log_archiver_mutant',
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
def test_job_log_archiver_mutants_are_observable(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    mutant_name: str,
) -> None:
    module = load_mutant(tmp_path, mutated_source(mutant_name))

    if mutant_name == 'swallows_archiver_exceptions':
        result = module.lambda_handler({
            'Records': [{'body': '{"detail":'}],
        }, None)

        assert result is None
        return

    if mutant_name == 'ignores_metadata_field_limit':
        monkeypatch.setattr(module, 'MAX_METADATA_FIELDS', 2)

        fields = module._flatten_metadata_fields({'a': 1, 'b': 2, 'c': 3})

        assert len(fields) == 3
        return

    if mutant_name == 'does_not_truncate_metadata_values':
        long_value = 'x' * (module.MAX_METADATA_VALUE_LENGTH + 1)

        fields = module._flatten_metadata_fields({'long': long_value})

        assert len(fields['long']) > module.MAX_METADATA_VALUE_LENGTH
        return

    raise AssertionError(f'Unhandled mutant: {mutant_name}')
