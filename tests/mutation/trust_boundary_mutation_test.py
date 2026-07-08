from __future__ import annotations

import importlib.util
import json
from pathlib import Path
from types import ModuleType

import pytest
from conftest import requires_aws

pytestmark = [pytest.mark.mutation, requires_aws]

SOURCE = Path(__file__).resolve().parents[2].joinpath(
    'modules/platform/forge_runners/forge_trust_validator/lambda/'
    'trust_common.py',
)

VALIDATOR_ROLE = 'arn:aws:iam::123456789012:role/validator'
TENANT_ROLE = 'arn:aws:iam::111111111111:role/tenant-role'

MUTANTS = {
    'allows_delay_outside_bounds': [
        (
            'if parsed < min_value or parsed > max_value:',
            'if False:',
        ),
    ],
    'accepts_deny_trust_statement': [
        (
            "if statement.get('Effect') != 'Allow':",
            'if False:',
        ),
    ],
    'accepts_wrong_principal_trust_statement': [
        (
            'return lambda_role_arn in aws_principals',
            'return True',
        ),
    ],
    'allows_session_policy_for_all_resources': [
        (
            "'Resource': tenant_role_arns,",
            "'Resource': '*',",
        ),
    ],
}


def load_mutant(tmp_path: Path, source: str) -> ModuleType:
    mutant_path = tmp_path / 'trust_common.py'
    mutant_path.write_text(source, encoding='utf-8')

    spec = importlib.util.spec_from_file_location(
        'trust_common_mutant',
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
def test_trust_boundary_mutants_are_observable(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    mutant_name: str,
) -> None:
    module = load_mutant(tmp_path, mutated_source(mutant_name))

    if mutant_name == 'allows_delay_outside_bounds':
        monkeypatch.setenv('VALIDATION_DELAY_SECONDS', '901')

        assert module.parse_env_int(
            'VALIDATION_DELAY_SECONDS',
            default=300,
            min_value=0,
            max_value=900,
        ) == 901
        return

    if mutant_name == 'accepts_deny_trust_statement':
        assert module.validator_trust_statement_matches({
            'Sid': module.TRUST_STATEMENT_SID,
            'Effect': 'Deny',
            'Principal': {'AWS': VALIDATOR_ROLE},
            'Action': 'sts:AssumeRole',
        }, VALIDATOR_ROLE)
        return

    if mutant_name == 'accepts_wrong_principal_trust_statement':
        assert module.validator_trust_statement_matches({
            'Sid': module.TRUST_STATEMENT_SID,
            'Effect': 'Allow',
            'Principal': {
                'AWS': 'arn:aws:iam::123456789012:role/someone-else',
            },
            'Action': 'sts:AssumeRole',
        }, VALIDATOR_ROLE)
        return

    if mutant_name == 'allows_session_policy_for_all_resources':
        policy = json.loads(module.build_session_policy_for_tenants([
            TENANT_ROLE,
        ]))

        assert policy['Statement'][0]['Resource'] == '*'
        return

    raise AssertionError(f'Unhandled mutant: {mutant_name}')
