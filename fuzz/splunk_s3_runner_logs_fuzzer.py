from __future__ import annotations

import json
import os
import sys
import types
from pathlib import Path
from typing import Any

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
    lambda_path = 'modules/integrations/splunk_cloud_s3_runner_logs/lambda'
    lambda_dir = repo_root / lambda_path
    if lambda_dir.exists():
        sys.path.insert(0, str(lambda_dir))


class _FakeAwsClient:
    def get_caller_identity(self) -> dict[str, str]:
        return {'Account': '123456789012'}

    def put_records(self, **_kwargs: Any) -> dict[str, Any]:
        return {'FailedRecordCount': 0, 'Records': []}


def _install_fake_boto3() -> None:
    fake_boto3 = types.ModuleType('boto3')
    fake_boto3.client = lambda *_args, **_kwargs: _FakeAwsClient()
    sys.modules['boto3'] = fake_boto3


def _safe_dict(value: Any, limit: int = 20) -> dict[str, Any]:
    if not isinstance(value, dict):
        return {}

    safe: dict[str, Any] = {}
    for key, child in value.items():
        if len(safe) >= limit:
            break
        if isinstance(key, str) and isinstance(child, (str, int, float, bool)):
            safe[key[:128]] = child
    return safe


def _valid_metadata_field(key: str, value: Any) -> bool:
    key_is_valid = isinstance(key, str) and bool(key)
    value_is_valid = isinstance(value, (str, int, float, bool))
    return key_is_valid and value_is_valid


_configure_runtime()
_install_fake_boto3()

with atheris.instrument_imports():
    import splunk_s3_runner_logs


def TestOneInput(data: bytes) -> None:
    if len(data) > 8192:
        return

    text = data.decode('utf-8', errors='replace')
    try:
        payload = json.loads(text)
    except (json.JSONDecodeError, RecursionError):
        payload = text

    fields = splunk_s3_runner_logs.normalize_metadata_fields(
        payload.get('fields') if isinstance(payload, dict) else payload
    )
    assert all(_valid_metadata_field(key, value)
               for key, value in fields.items())

    tags = _safe_dict(payload.get('tags') if isinstance(payload, dict) else {})
    key = str(payload.get('key', text) if isinstance(payload, dict) else text)
    key = key[:512] or 'runner.log'
    metadata_key = splunk_s3_runner_logs.metadata_key_for_object(key, tags)
    assert isinstance(metadata_key, str)
    assert metadata_key

    last_ts = None
    if isinstance(payload, dict) and isinstance(payload.get('last_ts'), (int, float)):
        last_ts = float(payload['last_ts'])
    timestamp = splunk_s3_runner_logs.extract_ts(text[:1024], last_ts)
    assert isinstance(timestamp, float)

    wrapped = splunk_s3_runner_logs.wrap_line(
        text[:2048],
        timestamp,
        'forge-fuzz-bucket',
        key,
        {str(k): str(v) for k, v in list(tags.items())[:10]},
        fields,
    )
    event = json.loads(wrapped)
    assert event['fields']['AccountId'] == '123456789012'
    assert event['source'].startswith('forge-fuzz-bucket:')


def main() -> None:
    atheris.Setup(sys.argv, TestOneInput)
    atheris.Fuzz()


if __name__ == '__main__':
    main()
