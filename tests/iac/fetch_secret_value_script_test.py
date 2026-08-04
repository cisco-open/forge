"""Unit tests for the cross-account secret fetch helper."""

from __future__ import annotations

import importlib.util
import json
import subprocess
from pathlib import Path
from types import SimpleNamespace

import pytest

pytestmark = pytest.mark.contract

SCRIPT_PATH = Path(__file__).resolve().parents[2].joinpath(
    'modules/integrations/github_webhook_relay_destination/scripts/',
    'fetch_secret_value.py',
)
SCRIPT_SPEC = importlib.util.spec_from_file_location(
    'fetch_secret_value', SCRIPT_PATH
)
assert SCRIPT_SPEC is not None and SCRIPT_SPEC.loader is not None
secret_helper = importlib.util.module_from_spec(SCRIPT_SPEC)
SCRIPT_SPEC.loader.exec_module(secret_helper)

READER_ROLE_ARN = 'arn:aws:iam::123456789012:role/reader'
SOURCE_ROLE_ARN = 'arn:aws:iam::210987654321:role/source-reader'
SECRET_ARN = (
    'arn:aws:secretsmanager:eu-central-1:210987654321:secret:webhook'
)


def _credentials(prefix: str) -> dict[str, str]:
    return {
        'AccessKeyId': f'{prefix}-access-key',
        'SecretAccessKey': f'{prefix}-secret-key',
        'SessionToken': f'{prefix}-session-token',
    }


def test_fetch_secret_value_uses_the_two_hop_role_chain(monkeypatch) -> None:
    calls = []
    reader_credentials = _credentials('reader')
    source_credentials = _credentials('source')
    outputs = iter(
        [
            json.dumps(reader_credentials),
            json.dumps(source_credentials),
            'webhook-secret\n',
        ]
    )

    def fake_run(command, **kwargs):
        calls.append((command, kwargs))
        return SimpleNamespace(stdout=next(outputs))

    monkeypatch.setattr(secret_helper.subprocess, 'run', fake_run)

    secret = secret_helper.fetch_secret_value(
        READER_ROLE_ARN,
        SOURCE_ROLE_ARN,
        SECRET_ARN,
        'eu-central-1',
        'forge-profile',
        'us-east-1',
        environment={
            'PATH': '/usr/bin',
            'AWS_PROFILE': 'ambient-profile',
        },
    )

    assert secret == 'webhook-secret'
    assert len(calls) == 3
    assert calls[0][0] == [
        'aws',
        'sts',
        'assume-role',
        '--role-arn',
        READER_ROLE_ARN,
        '--role-session-name',
        'reader-temp',
        '--profile',
        'forge-profile',
        '--region',
        'us-east-1',
        '--query',
        'Credentials',
        '--output',
        'json',
    ]
    assert calls[1][0] == [
        'aws',
        'sts',
        'assume-role',
        '--role-arn',
        SOURCE_ROLE_ARN,
        '--role-session-name',
        'source-temp',
        '--region',
        'us-east-1',
        '--query',
        'Credentials',
        '--output',
        'json',
    ]
    assert calls[2][0] == [
        'aws',
        'secretsmanager',
        'get-secret-value',
        '--secret-id',
        SECRET_ARN,
        '--region',
        'eu-central-1',
        '--query',
        'SecretString',
        '--output',
        'text',
    ]

    for _, kwargs in calls:
        assert kwargs['check'] is True
        assert kwargs['capture_output'] is True
        assert kwargs['text'] is True
        assert kwargs['env']['AWS_PAGER'] == ''

    second_hop_environment = calls[1][1]['env']
    assert second_hop_environment['AWS_ACCESS_KEY_ID'] == (
        reader_credentials['AccessKeyId']
    )
    assert second_hop_environment['AWS_SECRET_ACCESS_KEY'] == (
        reader_credentials['SecretAccessKey']
    )
    assert second_hop_environment['AWS_SESSION_TOKEN'] == (
        reader_credentials['SessionToken']
    )
    assert 'AWS_PROFILE' not in second_hop_environment

    secret_environment = calls[2][1]['env']
    assert secret_environment['AWS_ACCESS_KEY_ID'] == (
        source_credentials['AccessKeyId']
    )
    assert secret_environment['AWS_SECRET_ACCESS_KEY'] == (
        source_credentials['SecretAccessKey']
    )
    assert secret_environment['AWS_SESSION_TOKEN'] == (
        source_credentials['SessionToken']
    )
    assert 'AWS_PROFILE' not in secret_environment


def test_main_emits_terraform_external_data_json(monkeypatch, capsys) -> None:
    arguments = [
        READER_ROLE_ARN,
        SOURCE_ROLE_ARN,
        SECRET_ARN,
        'eu-central-1',
        'forge-profile',
        'us-east-1',
    ]
    monkeypatch.setattr(
        secret_helper,
        'fetch_secret_value',
        lambda *_arguments: 'secret with spaces and "quotes"',
    )

    assert secret_helper.main(arguments) == 0

    captured = capsys.readouterr()
    assert json.loads(captured.out) == {
        'secret_value': 'secret with spaces and "quotes"'
    }
    assert captured.err == ''


def test_assume_role_rejects_incomplete_credentials(monkeypatch) -> None:
    monkeypatch.setattr(
        secret_helper.subprocess,
        'run',
        lambda *_args, **_kwargs: SimpleNamespace(
            stdout='{"AccessKeyId":"only-one-value"}'
        ),
    )

    with pytest.raises(
        secret_helper.SecretFetchError,
        match='assume-role returned invalid credentials',
    ):
        secret_helper.assume_role(
            READER_ROLE_ARN,
            'reader-temp',
            'us-east-1',
            environment={},
            profile='forge-profile',
        )


def test_assume_role_rejects_non_string_credentials(monkeypatch) -> None:
    monkeypatch.setattr(
        secret_helper.subprocess,
        'run',
        lambda *_args, **_kwargs: SimpleNamespace(
            stdout=json.dumps(
                {
                    'AccessKeyId': 'access-key',
                    'SecretAccessKey': None,
                    'SessionToken': 'session-token',
                }
            )
        ),
    )

    with pytest.raises(
        secret_helper.SecretFetchError,
        match='assume-role returned invalid credentials',
    ):
        secret_helper.assume_role(
            READER_ROLE_ARN,
            'reader-temp',
            'us-east-1',
            environment={},
            profile='forge-profile',
        )


def test_aws_cli_failure_is_reported_without_emitting_json(
    monkeypatch,
    capsys,
) -> None:
    def fail_run(*_args, **_kwargs):
        raise subprocess.CalledProcessError(
            1,
            ['aws', 'sts', 'assume-role'],
            stderr='AccessDeniedException',
        )

    monkeypatch.setattr(secret_helper.subprocess, 'run', fail_run)

    result = secret_helper.main(
        [
            READER_ROLE_ARN,
            SOURCE_ROLE_ARN,
            SECRET_ARN,
            'eu-central-1',
            'forge-profile',
            'us-east-1',
        ]
    )

    captured = capsys.readouterr()
    assert result == 1
    assert captured.out == ''
    assert 'AccessDeniedException' in captured.err


def test_aws_cli_failure_does_not_report_captured_standard_output(
    monkeypatch,
) -> None:
    def fail_run(*_args, **_kwargs):
        raise subprocess.CalledProcessError(
            1,
            ['aws', 'sts', 'assume-role'],
            output='temporary-credentials-must-not-leak',
        )

    monkeypatch.setattr(secret_helper.subprocess, 'run', fail_run)

    with pytest.raises(
        secret_helper.SecretFetchError,
        match='AWS CLI exited with status 1',
    ) as failure:
        secret_helper.run_aws([], environment={})

    assert 'temporary-credentials-must-not-leak' not in str(failure.value)


def test_main_rejects_an_invalid_argument_count(capsys) -> None:
    assert secret_helper.main([]) == 2

    captured = capsys.readouterr()
    assert captured.out == ''
    assert 'Usage: fetch_secret_value.py' in captured.err
