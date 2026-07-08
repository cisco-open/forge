from __future__ import annotations

import base64
import importlib.util
from pathlib import Path
from types import ModuleType

import pytest
from conftest import requires_aws

pytestmark = [pytest.mark.mutation, requires_aws]

SOURCE = Path(__file__).resolve().parents[2].joinpath(
    'modules/platform/forge_runners/github_app_runner_group/lambda/'
    'github_app_runner_group.py',
)

MUTANTS = {
    'reads_ssm_without_decryption': [
        (
            'SSM.get_parameter(Name=secret_name, WithDecryption=True)',
            'SSM.get_parameter(Name=secret_name, WithDecryption=False)',
        ),
    ],
    'skips_selected_repository_listing': [
        (
            "if repo_selection == 'selected':",
            'if False:',
        ),
    ],
}


class FakeSsm:
    def __init__(self) -> None:
        self.calls: list[dict] = []

    def get_parameter(self, **kwargs):
        self.calls.append(kwargs)
        return {'Parameter': {'Value': 'secret-value'}}


def load_mutant(tmp_path: Path, source: str) -> ModuleType:
    mutant_path = tmp_path / 'github_app_runner_group.py'
    mutant_path.write_text(source, encoding='utf-8')

    spec = importlib.util.spec_from_file_location(
        'github_app_runner_group_mutant',
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
def test_github_app_runner_group_mutants_are_observable(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    mutant_name: str,
) -> None:
    module = load_mutant(tmp_path, mutated_source(mutant_name))

    if mutant_name == 'reads_ssm_without_decryption':
        fake_ssm = FakeSsm()
        module.SSM = fake_ssm

        assert module.get_secret('/forge/private-key') == 'secret-value'
        assert fake_ssm.calls == [{
            'Name': '/forge/private-key',
            'WithDecryption': False,
        }]
        return

    if mutant_name == 'skips_selected_repository_listing':
        secrets = {
            '/forge/app_id': '12345',
            '/forge/private_key': base64.b64encode(b'FAKE-KEY').decode(),
            '/forge/installation_id': '999',
        }
        for key, value in {
            'SECRET_NAME_APP_ID': '/forge/app_id',
            'SECRET_NAME_PRIVATE_KEY': '/forge/private_key',
            'SECRET_NAME_INSTALLATION_ID': '/forge/installation_id',
            'REPOSITORY_SELECTION': 'selected',
            'ORGANIZATION': 'acme',
            'GITHUB_API': 'https://api.github.test',
            'RUNNER_GROUP_NAME': 'forge-small',
        }.items():
            monkeypatch.setenv(key, value)

        list_calls = []
        saved = {}
        monkeypatch.setattr(module, 'get_secret', lambda name: secrets[name])
        monkeypatch.setattr(module, 'generate_jwt', lambda *_args: 'jwt-token')
        monkeypatch.setattr(
            module,
            'get_installation_access_token',
            lambda *_args: 'installation-token',
        )
        monkeypatch.setattr(
            module,
            'list_repositories',
            lambda *_args: list_calls.append(True) or [
                {'id': 10, 'full_name': 'acme/app'},
            ],
        )
        monkeypatch.setattr(
            module,
            'save_to_runner_group',
            lambda token, api, org, group, repos, visibility: saved.update({
                'token': token,
                'api': api,
                'org': org,
                'group': group,
                'repos': repos,
                'visibility': visibility,
            }),
        )

        module.lambda_handler({}, None)

        assert list_calls == []
        assert saved['visibility'] == 'selected'
        assert saved['repos'] == []
        return

    raise AssertionError(f'Unhandled mutant: {mutant_name}')
