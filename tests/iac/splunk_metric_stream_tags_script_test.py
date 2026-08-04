"""Unit tests for the Splunk Metric Stream tag helper."""

from __future__ import annotations

import importlib.util
import io
import subprocess
import sys
from pathlib import Path

import pytest

pytestmark = pytest.mark.contract

REPO_ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = REPO_ROOT / (
    'modules/integrations/splunk_o11y_aws_integration'
)
SCRIPT_PATH = MODULE_PATH / (
    'scripts/manage_cloudwatch_metric_stream_tags.py'
)
TERRAFORM_PATH = MODULE_PATH / 'metric_stream_tags.tf'
METRIC_STREAM_ARN = (
    'arn:aws:cloudwatch:us-east-1:123456789012:'
    'metric-stream/splunk-metric-stream-test'
)

SCRIPT_SPEC = importlib.util.spec_from_file_location(
    'manage_cloudwatch_metric_stream_tags',
    SCRIPT_PATH,
)
assert SCRIPT_SPEC is not None and SCRIPT_SPEC.loader is not None
metric_stream_tags = importlib.util.module_from_spec(SCRIPT_SPEC)
sys.modules[SCRIPT_SPEC.name] = metric_stream_tags
SCRIPT_SPEC.loader.exec_module(metric_stream_tags)


class FakeAws:
    """Record AWS CLI calls and return one deterministic scenario."""

    def __init__(self, scenario: str = 'success'):
        self.scenario = scenario
        self.calls: list[list[str]] = []
        self.list_attempts = 0
        self.tag_attempts = 0

    def __call__(self, command, **kwargs):
        self.calls.append(command)
        assert command[:2] == ['aws', 'cloudwatch']
        assert kwargs['check'] is False
        assert kwargs['stdout'] == subprocess.PIPE
        assert kwargs['text'] is True

        operation = command[2]
        if operation == 'list-metric-streams':
            assert kwargs['stderr'] == subprocess.PIPE
            self.list_attempts += 1
            if self.scenario == 'missing':
                return self._result(command, stdout='None\n')
            if self.scenario == 'multiple':
                return self._result(
                    command,
                    stdout=f'{METRIC_STREAM_ARN}\t{METRIC_STREAM_ARN}-second\n',
                )
            if self.scenario == 'list-error':
                return self._result(
                    command,
                    returncode=9,
                    stderr='ListMetricStreams failed\n',
                )
            return self._result(command, stdout=f'{METRIC_STREAM_ARN}\n')

        assert kwargs['stderr'] == subprocess.STDOUT
        if operation == 'tag-resource':
            self.tag_attempts += 1
            if self.scenario == 'tag-race' and self.tag_attempts == 1:
                return self._result(
                    command,
                    returncode=1,
                    stdout='ResourceNotFoundException\n',
                )
            if self.scenario == 'tag-error':
                return self._result(
                    command,
                    returncode=1,
                    stdout='AccessDeniedException\n',
                )
            return self._result(command)

        if operation == 'untag-resource':
            if self.scenario == 'untag-missing':
                return self._result(
                    command,
                    returncode=1,
                    stdout='ResourceNotFoundException\n',
                )
            if self.scenario == 'untag-error':
                return self._result(
                    command,
                    returncode=1,
                    stdout='AccessDeniedException\n',
                )
            return self._result(command)

        raise AssertionError(f'Unexpected AWS operation: {operation}')

    @staticmethod
    def _result(command, returncode=0, stdout='', stderr=''):
        return subprocess.CompletedProcess(
            command,
            returncode,
            stdout=stdout,
            stderr=stderr,
        )


def runtime_environment(tag_count: int = 1) -> dict[str, str]:
    return {
        'AWS_PROFILE': 'test',
        'AWS_REGION': 'us-east-1',
        'STREAM_NAME_PREFIX': 'splunk-metric-stream-',
        'TAG_COUNT': str(tag_count),
        'TAGS_JSON': '[{"Key":"Env","Value":"test"}]',
        'TAG_KEYS_JSON': '["Env"]',
    }


def run_main(
    mode: str,
    *,
    scenario: str = 'success',
    tag_count: int = 1,
    environment: dict[str, str] | None = None,
) -> tuple[int, FakeAws, list[float], str, str]:
    fake_aws = FakeAws(scenario)
    sleeps: list[float] = []
    stdout = io.StringIO()
    stderr = io.StringIO()
    result = metric_stream_tags.main(
        [mode],
        environ=(
            runtime_environment(tag_count)
            if environment is None
            else environment
        ),
        runner=fake_aws,
        sleep=sleeps.append,
        output_stream=stdout,
        error_stream=stderr,
    )
    return result, fake_aws, sleeps, stdout.getvalue(), stderr.getvalue()


def test_apply_tags_the_single_matching_stream() -> None:
    result, fake_aws, sleeps, stdout, stderr = run_main('apply')

    assert result == 0
    assert stderr == ''
    assert sleeps == []
    assert [call[2] for call in fake_aws.calls] == [
        'list-metric-streams',
        'tag-resource',
    ]
    assert fake_aws.calls[0] == [
        'aws',
        'cloudwatch',
        'list-metric-streams',
        '--region',
        'us-east-1',
        '--query',
        "Entries[?starts_with(Name, 'splunk-metric-stream-')].Arn",
        '--output',
        'text',
    ]
    assert fake_aws.calls[1] == [
        'aws',
        'cloudwatch',
        'tag-resource',
        '--region',
        'us-east-1',
        '--resource-arn',
        METRIC_STREAM_ARN,
        '--tags',
        '[{"Key":"Env","Value":"test"}]',
    ]
    assert METRIC_STREAM_ARN in stdout


def test_remove_untags_the_single_matching_stream() -> None:
    result, fake_aws, sleeps, stdout, stderr = run_main('remove')

    assert result == 0
    assert stderr == ''
    assert sleeps == []
    assert [call[2] for call in fake_aws.calls] == [
        'list-metric-streams',
        'untag-resource',
    ]
    assert fake_aws.calls[1] == [
        'aws',
        'cloudwatch',
        'untag-resource',
        '--region',
        'us-east-1',
        '--resource-arn',
        METRIC_STREAM_ARN,
        '--tag-keys',
        '["Env"]',
    ]
    assert METRIC_STREAM_ARN in stdout


@pytest.mark.parametrize('mode', ['apply', 'remove'])
def test_ambiguous_stream_matches_fail_safely(mode: str) -> None:
    result, fake_aws, _sleeps, _stdout, stderr = run_main(
        mode,
        scenario='multiple',
    )

    assert result == 2
    assert [call[2] for call in fake_aws.calls] == ['list-metric-streams']
    assert 'Expected exactly one CloudWatch Metric Stream' in stderr
    assert 'found 2' in stderr
    assert f'  {METRIC_STREAM_ARN}\n' in stderr


def test_apply_retries_until_the_stream_is_available(monkeypatch) -> None:
    monkeypatch.setattr(metric_stream_tags, 'MAX_ATTEMPTS', 3)

    result, fake_aws, sleeps, _stdout, stderr = run_main(
        'apply',
        scenario='missing',
    )

    assert result == 1
    assert [call[2] for call in fake_aws.calls] == [
        'list-metric-streams',
    ] * 3
    assert sleeps == [15, 15]
    assert 'was not available after 3 attempts' in stderr


def test_retry_window_remains_fifteen_minutes() -> None:
    assert metric_stream_tags.MAX_ATTEMPTS == 60
    assert metric_stream_tags.RETRY_SECONDS == 15


def test_apply_retries_a_tag_resource_not_found_race() -> None:
    result, fake_aws, sleeps, _stdout, stderr = run_main(
        'apply',
        scenario='tag-race',
    )

    assert result == 0
    assert stderr == ''
    assert [call[2] for call in fake_aws.calls] == [
        'list-metric-streams',
        'tag-resource',
        'list-metric-streams',
        'tag-resource',
    ]
    assert sleeps == [15]


def test_remove_accepts_an_already_missing_stream() -> None:
    result, fake_aws, _sleeps, stdout, stderr = run_main(
        'remove',
        scenario='missing',
    )

    assert result == 0
    assert stderr == ''
    assert [call[2] for call in fake_aws.calls] == ['list-metric-streams']
    assert 'no tags remain to remove' in stdout


def test_remove_accepts_resource_not_found_from_untag() -> None:
    result, fake_aws, _sleeps, stdout, stderr = run_main(
        'remove',
        scenario='untag-missing',
    )

    assert result == 0
    assert stderr == ''
    assert [call[2] for call in fake_aws.calls] == [
        'list-metric-streams',
        'untag-resource',
    ]
    assert 'no tags remain to remove' in stdout


@pytest.mark.parametrize(
    ('mode', 'scenario'),
    [('apply', 'tag-error'), ('remove', 'untag-error')],
)
def test_tag_permission_failures_are_not_ignored(
    mode: str,
    scenario: str,
) -> None:
    result, fake_aws, _sleeps, _stdout, stderr = run_main(
        mode,
        scenario=scenario,
    )

    assert result == 1
    assert len(fake_aws.calls) == 2
    assert 'AccessDeniedException' in stderr


@pytest.mark.parametrize('mode', ['apply', 'remove'])
def test_list_metric_stream_failures_are_not_ignored(mode: str) -> None:
    result, fake_aws, _sleeps, _stdout, stderr = run_main(
        mode,
        scenario='list-error',
    )

    assert result == 2
    assert [call[2] for call in fake_aws.calls] == ['list-metric-streams']
    assert 'ListMetricStreams failed' in stderr


@pytest.mark.parametrize('mode', ['apply', 'remove'])
def test_zero_tags_do_not_call_aws(mode: str) -> None:
    result, fake_aws, _sleeps, stdout, stderr = run_main(
        mode,
        tag_count=0,
    )

    assert result == 0
    assert stderr == ''
    assert fake_aws.calls == []
    assert f'No CloudWatch Metric Stream tags to {mode}' in stdout


def test_invalid_mode_is_rejected_without_calling_aws() -> None:
    result, fake_aws, _sleeps, _stdout, stderr = run_main('invalid')

    assert result == 2
    assert fake_aws.calls == []
    assert 'Usage:' in stderr


@pytest.mark.parametrize(
    ('mode', 'missing_name'),
    [('apply', 'TAGS_JSON'), ('remove', 'TAG_KEYS_JSON')],
)
def test_nonzero_tags_require_the_operation_payload(
    mode: str,
    missing_name: str,
) -> None:
    environment = runtime_environment()
    environment.pop(missing_name)

    result, fake_aws, _sleeps, _stdout, stderr = run_main(
        mode,
        environment=environment,
    )

    assert result == 1
    assert fake_aws.calls == []
    assert f'{missing_name} must be set' in stderr


def test_terraform_runs_both_modes_from_the_module_directory() -> None:
    terraform_source = TERRAFORM_PATH.read_text(encoding='utf-8')

    assert terraform_source.count('working_dir = path.module') == 2
    assert (
        'python3 ./scripts/manage_cloudwatch_metric_stream_tags.py apply'
        in terraform_source
    )
    assert (
        'python3 ./scripts/manage_cloudwatch_metric_stream_tags.py remove'
        in terraform_source
    )
    assert (
        'filesha256('
        '"${path.module}/scripts/manage_cloudwatch_metric_stream_tags.py"'
        ')' in terraform_source
    )
