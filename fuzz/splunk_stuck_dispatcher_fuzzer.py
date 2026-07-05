from __future__ import annotations

import base64
import binascii
import json
import os
import sys
import urllib.parse
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
        'modules/integrations/splunk_stuck_workflow_job_dispatcher/lambda'
    )
    lambda_dir = repo_root / lambda_path
    if lambda_dir.exists():
        sys.path.insert(0, str(lambda_dir))


def _event(body: str, content_type: str, *, encoded: bool) -> dict[str, Any]:
    if encoded:
        body = base64.b64encode(body.encode('utf-8')).decode('ascii')

    return {
        'headers': {
            'content-type': content_type,
            'user-agent': 'clusterfuzzlite',
        },
        'body': body,
        'isBase64Encoded': encoded,
        'pathParameters': {'token': body[:128]},
        'requestContext': {
            'requestId': 'fuzz',
            'routeKey': 'POST /redrive/{token}',
            'http': {
                'method': 'POST',
                'path': '/redrive/fuzz',
                'sourceIp': '127.0.0.1',
            },
        },
    }


_configure_runtime()

with atheris.instrument_imports():
    import handler as stuck_handler


def TestOneInput(data: bytes) -> None:
    if len(data) > 8192:
        return

    text = data.decode('utf-8', errors='replace')
    body = text
    if data[:1] == b'f':
        body = urllib.parse.urlencode({'payload': text})

    content_type = (
        'application/x-www-form-urlencoded'
        if data[:1] == b'f'
        else 'application/json'
    )
    event = _event(body, content_type, encoded=data[:1] == b'b')
    stuck_handler.request_metadata(event)

    try:
        payload = stuck_handler.parse_body(event)
    except (binascii.Error, json.JSONDecodeError, UnicodeDecodeError, ValueError):
        payload = {}

    if not isinstance(payload, dict):
        return

    results = stuck_handler.extract_results(payload)
    assert all(isinstance(item, dict) for item in results)

    for result in results[:20]:
        try:
            normalized = stuck_handler.normalize_result(result)
        except (TypeError, ValueError):
            continue
        assert stuck_handler.parse_queued_url(
            normalized['queued_url']) is not None
        queue_name = stuck_handler.parse_queued_url(normalized['queued_url'])
        runner_name = stuck_handler.runner_name_from_queue(queue_name)
        assert isinstance(runner_name, str)
        assert stuck_handler.dedupe_key(normalized)

    stuck_handler.split_multivalue(text)
    stuck_handler.runner_name_from_queue(text[:256])
    stuck_handler.parse_queued_url(text[:512])


def main() -> None:
    atheris.Setup(sys.argv, TestOneInput)
    atheris.Fuzz()


if __name__ == '__main__':
    main()
