from __future__ import annotations

import os
import sys
from pathlib import Path

import atheris

ENV_NAME = 'FORGE_FUZZ_ENV'


def _configure_runtime() -> None:
    for key, value in {
        'AWS_ACCESS_KEY_ID': 'fuzzing',
        'AWS_SECRET_ACCESS_KEY': 'fuzzing',
        'AWS_SECURITY_TOKEN': 'fuzzing',
        'AWS_SESSION_TOKEN': 'fuzzing',
        'AWS_DEFAULT_REGION': 'us-west-2',
        'AWS_REGION': 'us-west-2',
        'AWS_EC2_METADATA_DISABLED': 'true',
    }.items():
        os.environ.setdefault(key, value)

    repo_root = Path(__file__).resolve().parents[1]
    lambda_path = 'modules/platform/forge_runners/forge_trust_validator/lambda'
    lambda_dir = repo_root / lambda_path
    if lambda_dir.exists():
        sys.path.insert(0, str(lambda_dir))


_configure_runtime()

with atheris.instrument_imports():
    import trust_common


def TestOneInput(data: bytes) -> None:
    if len(data) > 4096:
        return

    text = data.decode('utf-8', errors='replace')
    if '\x00' in text:
        return

    os.environ[ENV_NAME] = text
    try:
        values = trust_common.parse_env_list(ENV_NAME)
        assert isinstance(values, list)
        assert all(isinstance(value, str) and value.strip()
                   for value in values)

        try:
            parsed_int = trust_common.parse_env_int(ENV_NAME, 10, -1000, 1000)
        except RuntimeError:
            parsed_int = 10
        assert -1000 <= parsed_int <= 1000

        role_name = trust_common.get_forge_role_name(text)
        assert isinstance(role_name, str)
        if '/' in text:
            assert role_name == text.rsplit('/', 1)[-1]
    finally:
        os.environ.pop(ENV_NAME, None)


def main() -> None:
    atheris.Setup(sys.argv, TestOneInput)
    atheris.Fuzz()


if __name__ == '__main__':
    main()
