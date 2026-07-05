from __future__ import annotations

import json
import os
import sys
from pathlib import Path

import atheris


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
    lambda_path = 'modules/platform/forge_runners/redrive_deadletter/lambda'
    lambda_dir = repo_root / lambda_path
    if lambda_dir.exists():
        sys.path.insert(0, str(lambda_dir))


_configure_runtime()

with atheris.instrument_imports():
    import redrive_deadletter


def TestOneInput(data: bytes) -> None:
    if len(data) > 16384:
        return

    try:
        raw = data.decode('utf-8')
    except UnicodeDecodeError:
        return

    try:
        mappings = redrive_deadletter.parse_sqs_map(raw)
    except Exception as err:
        if isinstance(err, (KeyboardInterrupt, SystemExit)):
            raise
        return

    assert isinstance(mappings, list)
    for mapping in mappings:
        assert set(mapping) == {'key', 'main', 'dlq'}
        assert all(isinstance(value, str) for value in mapping.values())

    encoded = json.dumps({
        item['key']: {'main': item['main'], 'dlq': item['dlq']}
        for item in mappings[:20]
    })
    reparsed = redrive_deadletter.parse_sqs_map(encoded)
    assert len(reparsed) == len(mappings[:20])


def main() -> None:
    atheris.Setup(sys.argv, TestOneInput)
    atheris.Fuzz()


if __name__ == '__main__':
    main()
