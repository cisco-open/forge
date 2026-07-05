from __future__ import annotations

import json
import os
import sys
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
    lambda_path = (
        'modules/platform/forge_runners/github_actions_job_logs/lambda/'
        'job_log_archiver'
    )
    lambda_dir = repo_root / lambda_path
    if lambda_dir.exists():
        sys.path.insert(0, str(lambda_dir))


def _too_deep_or_large(value: Any) -> bool:
    stack = [(value, 0)]
    nodes_seen = 0

    while stack:
        current, depth = stack.pop()
        nodes_seen += 1
        if depth > 32 or nodes_seen > 1000:
            return True
        if isinstance(current, dict):
            stack.extend((child, depth + 1) for child in current.values())
        elif isinstance(current, list):
            stack.extend((child, depth + 1) for child in current)

    return False


def _parseable_archiver_event(payload: Any) -> bool:
    if not isinstance(payload, dict):
        return False

    if 'detail' not in payload:
        return True

    detail = payload.get('detail')
    if not isinstance(detail, dict):
        return False

    workflow_job = detail.get('workflow_job')
    return workflow_job is None or isinstance(workflow_job, dict)


_configure_runtime()

with atheris.instrument_imports():
    import job_log_archiver


def TestOneInput(data: bytes) -> None:
    if len(data) > 8192:
        return

    try:
        text = data.decode('utf-8')
        payload = json.loads(text)
    except (json.JSONDecodeError, RecursionError, UnicodeDecodeError):
        return

    if _too_deep_or_large(payload):
        return

    detail = payload if isinstance(payload, dict) else {'payload': payload}
    fields = job_log_archiver._flatten_metadata_fields(detail)
    assert len(fields) <= job_log_archiver.MAX_METADATA_FIELDS
    assert all(isinstance(key, str) and key for key in fields)

    metadata = job_log_archiver._metadata_payload(
        detail, 'log-key', 'event-key')
    assert metadata['field_count'] == len(metadata['fields'])

    if _parseable_archiver_event(payload):
        gh_event, workflow_job = job_log_archiver._parse_event({
            'Records': [{'body': text}],
        })
        assert isinstance(gh_event, dict)
        assert isinstance(workflow_job, dict)


def main() -> None:
    atheris.Setup(sys.argv, TestOneInput)
    atheris.Fuzz()


if __name__ == '__main__':
    main()
