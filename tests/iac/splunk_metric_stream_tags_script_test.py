"""Hermetic tests for the Splunk Metric Stream tag helper."""

from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

import pytest

pytestmark = pytest.mark.contract

REPO_ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = REPO_ROOT / (
    'modules/integrations/splunk_o11y_aws_integration'
)
SCRIPT_RELATIVE_PATH = Path('scripts/manage_cloudwatch_metric_stream_tags.sh')
TERRAFORM_PATH = MODULE_PATH / 'metric_stream_tags.tf'
METRIC_STREAM_ARN = (
    'arn:aws:cloudwatch:us-east-1:123456789012:'
    'metric-stream/splunk-metric-stream-test'
)

FAKE_AWS = '''#!/usr/bin/env python3
import json
import os
import sys
from pathlib import Path

scenario = os.environ['FAKE_AWS_SCENARIO']
log_path = Path(os.environ['FAKE_AWS_LOG'])
state_path = Path(os.environ['FAKE_AWS_STATE'])
arn = os.environ['FAKE_METRIC_STREAM_ARN']

with log_path.open('a', encoding='utf-8') as log:
    log.write(json.dumps(sys.argv[1:]) + '\\n')

if sys.argv[1] != 'cloudwatch':
    raise SystemExit(99)

operation = sys.argv[2]

if operation == 'list-metric-streams':
    if scenario == 'missing':
        print('None')
    elif scenario == 'multiple':
        print(f'{arn}-newest')
    elif scenario == 'malformed-multiple':
        print(f'{arn}\\t{arn}-second')
    elif scenario == 'list-error':
        print('ListMetricStreams failed', file=sys.stderr)
        raise SystemExit(9)
    else:
        print(arn)
elif operation == 'tag-resource':
    if scenario == 'tag-race' and not state_path.exists():
        state_path.write_text('retried', encoding='utf-8')
        print('ResourceNotFoundException', file=sys.stderr)
        raise SystemExit(1)
    if scenario == 'tag-error':
        print('AccessDeniedException', file=sys.stderr)
        raise SystemExit(1)
elif operation == 'untag-resource':
    if scenario == 'untag-missing':
        print('ResourceNotFoundException', file=sys.stderr)
        raise SystemExit(1)
    if scenario == 'untag-error':
        print('AccessDeniedException', file=sys.stderr)
        raise SystemExit(1)
else:
    raise SystemExit(98)
'''


def run_script(
    tmp_path: Path,
    mode: str,
    scenario: str = 'success',
    tag_count: int = 1,
    extra_env: dict[str, str] | None = None,
) -> tuple[subprocess.CompletedProcess[str], list[list[str]]]:
    bin_dir = tmp_path / 'bin'
    bin_dir.mkdir()
    fake_aws = bin_dir / 'aws'
    fake_aws.write_text(FAKE_AWS, encoding='utf-8')
    fake_aws.chmod(0o755)
    fake_sleep = bin_dir / 'sleep'
    fake_sleep.write_text('#!/usr/bin/env bash\nexit 0\n', encoding='utf-8')
    fake_sleep.chmod(0o755)

    log_path = tmp_path / 'aws-calls.jsonl'
    env = os.environ.copy()
    env.update(
        {
            'AWS_PAGER': '',
            'AWS_PROFILE': 'test',
            'AWS_REGION': 'us-east-1',
            'FAKE_AWS_LOG': str(log_path),
            'FAKE_AWS_SCENARIO': scenario,
            'FAKE_AWS_STATE': str(tmp_path / 'aws-state'),
            'FAKE_METRIC_STREAM_ARN': METRIC_STREAM_ARN,
            'PATH': f'{bin_dir}:{env["PATH"]}',
            'STREAM_NAME_PREFIX': 'splunk-metric-stream-',
            'TAG_COUNT': str(tag_count),
            'TAGS_JSON': '[{"Key":"Env","Value":"test"}]',
            'TAG_KEYS_JSON': '["Env"]',
        }
    )
    if extra_env:
        env.update(extra_env)

    result = subprocess.run(
        [f'./{SCRIPT_RELATIVE_PATH.as_posix()}', mode],
        check=False,
        cwd=MODULE_PATH,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    calls = []
    if log_path.exists():
        calls = [
            json.loads(line)
            for line in log_path.read_text(encoding='utf-8').splitlines()
        ]
    return result, calls


def test_apply_tags_the_single_matching_stream(tmp_path: Path) -> None:
    result, calls = run_script(tmp_path, 'apply')

    assert result.returncode == 0
    assert [call[1] for call in calls] == [
        'list-metric-streams',
        'tag-resource',
    ]
    assert calls[0] == [
        'cloudwatch',
        'list-metric-streams',
        '--region',
        'us-east-1',
        '--query',
        (
            'max_by(Entries[?starts_with(Name, '
            "'splunk-metric-stream-')], &CreationDate).Arn"
        ),
        '--output',
        'text',
    ]
    assert calls[1] == [
        'cloudwatch',
        'tag-resource',
        '--region',
        'us-east-1',
        '--resource-arn',
        METRIC_STREAM_ARN,
        '--tags',
        '[{"Key":"Env","Value":"test"}]',
    ]
    assert METRIC_STREAM_ARN in result.stdout


def test_remove_untags_the_single_matching_stream(tmp_path: Path) -> None:
    result, calls = run_script(tmp_path, 'remove')

    assert result.returncode == 0
    assert [call[1] for call in calls] == [
        'list-metric-streams',
        'untag-resource',
    ]
    assert calls[1] == [
        'cloudwatch',
        'untag-resource',
        '--region',
        'us-east-1',
        '--resource-arn',
        METRIC_STREAM_ARN,
        '--tag-keys',
        '["Env"]',
    ]
    assert METRIC_STREAM_ARN in result.stdout


@pytest.mark.parametrize(
    ('mode', 'operation'),
    [('apply', 'tag-resource'), ('remove', 'untag-resource')],
)
def test_multiple_stream_matches_select_the_newest(
    tmp_path: Path,
    mode: str,
    operation: str,
) -> None:
    result, calls = run_script(tmp_path, mode, scenario='multiple')

    assert result.returncode == 0
    assert [call[1] for call in calls] == [
        'list-metric-streams',
        operation,
    ]
    assert calls[1][calls[1].index('--resource-arn') + 1] == (
        f'{METRIC_STREAM_ARN}-newest'
    )


@pytest.mark.parametrize('mode', ['apply', 'remove'])
def test_unexpected_multiple_query_results_fail_safely(
    tmp_path: Path,
    mode: str,
) -> None:
    result, calls = run_script(tmp_path, mode, scenario='malformed-multiple')

    assert result.returncode == 2
    assert [call[1] for call in calls] == ['list-metric-streams']
    assert 'Expected one newest CloudWatch Metric Stream' in result.stderr
    assert 'query returned 2' in result.stderr


def test_apply_retries_until_the_stream_is_available(tmp_path: Path) -> None:
    result, calls = run_script(tmp_path, 'apply', scenario='missing')

    assert result.returncode == 1
    assert [call[1] for call in calls] == ['list-metric-streams'] * 60
    assert 'was not available after 60 attempts' in result.stderr


def test_apply_retries_a_tag_resource_not_found_race(tmp_path: Path) -> None:
    result, calls = run_script(tmp_path, 'apply', scenario='tag-race')

    assert result.returncode == 0
    assert [call[1] for call in calls] == [
        'list-metric-streams',
        'tag-resource',
        'list-metric-streams',
        'tag-resource',
    ]


def test_remove_accepts_an_already_missing_stream(tmp_path: Path) -> None:
    result, calls = run_script(tmp_path, 'remove', scenario='missing')

    assert result.returncode == 0
    assert [call[1] for call in calls] == ['list-metric-streams']
    assert 'no tags remain to remove' in result.stdout


def test_remove_accepts_resource_not_found_from_untag(tmp_path: Path) -> None:
    result, calls = run_script(tmp_path, 'remove', scenario='untag-missing')

    assert result.returncode == 0
    assert [call[1] for call in calls] == [
        'list-metric-streams',
        'untag-resource',
    ]
    assert 'no tags remain to remove' in result.stdout


def test_remove_ignores_apply_retry_controls(tmp_path: Path) -> None:
    result, calls = run_script(
        tmp_path,
        'remove',
        extra_env={
            'METRIC_STREAM_MAX_ATTEMPTS': 'invalid',
            'METRIC_STREAM_RETRY_SECONDS': 'invalid',
        },
    )

    assert result.returncode == 0
    assert [call[1] for call in calls] == [
        'list-metric-streams',
        'untag-resource',
    ]


@pytest.mark.parametrize(
    ('mode', 'scenario'),
    [('apply', 'tag-error'), ('remove', 'untag-error')],
)
def test_tag_permission_failures_are_not_ignored(
    tmp_path: Path,
    mode: str,
    scenario: str,
) -> None:
    result, calls = run_script(tmp_path, mode, scenario=scenario)

    assert result.returncode == 1
    assert len(calls) == 2
    assert 'AccessDeniedException' in result.stderr


@pytest.mark.parametrize('mode', ['apply', 'remove'])
def test_list_metric_stream_failures_are_not_ignored(
    tmp_path: Path,
    mode: str,
) -> None:
    result, calls = run_script(tmp_path, mode, scenario='list-error')

    assert result.returncode == 2
    assert [call[1] for call in calls] == ['list-metric-streams']
    assert 'ListMetricStreams failed' in result.stderr


@pytest.mark.parametrize('mode', ['apply', 'remove'])
def test_zero_tags_do_not_call_aws(tmp_path: Path, mode: str) -> None:
    result, calls = run_script(tmp_path, mode, tag_count=0)

    assert result.returncode == 0
    assert calls == []
    assert f'No CloudWatch Metric Stream tags to {mode}' in result.stdout


def test_invalid_mode_is_rejected_without_calling_aws(tmp_path: Path) -> None:
    result, calls = run_script(tmp_path, 'invalid')

    assert result.returncode == 2
    assert calls == []
    assert 'Usage:' in result.stderr


def test_terraform_runs_both_modes_from_the_module_directory() -> None:
    terraform_source = TERRAFORM_PATH.read_text(encoding='utf-8')

    assert terraform_source.count('working_dir = path.module') == 2
    assert './scripts/manage_cloudwatch_metric_stream_tags.sh apply' in (
        terraform_source
    )
    assert './scripts/manage_cloudwatch_metric_stream_tags.sh remove' in (
        terraform_source
    )
