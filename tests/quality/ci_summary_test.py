import argparse
import importlib.util
import json
import sys
from pathlib import Path

SUMMARY_MODULE_PATH = Path(__file__).resolve(
).parents[2] / 'scripts' / 'ci_summary.py'
SUMMARY_SPEC = importlib.util.spec_from_file_location(
    'forge_ci_summary', SUMMARY_MODULE_PATH)
ci_summary = importlib.util.module_from_spec(SUMMARY_SPEC)
sys.modules[SUMMARY_SPEC.name] = ci_summary
SUMMARY_SPEC.loader.exec_module(ci_summary)


def test_build_summary_counts_junit_results(tmp_path: Path) -> None:
    junit = tmp_path / 'pytest-results.xml'
    junit.write_text(
        """<?xml version="1.0" encoding="utf-8"?>
<testsuites>
  <testsuite name="pytest" tests="4" failures="1" errors="0" skipped="1" time="1.25" />
</testsuites>
""",
        encoding='utf-8',
    )

    markdown = ci_summary.build_summary(
        argparse.Namespace(
            title='Example tests',
            input_markdown=None,
            junit=[f"Example={junit}"],
            coverage=None,
        )
    )

    assert '**Result:** failed' in markdown
    assert '| Example | 2 | 1 | 0 | 1 | 4 | 1.25s | failed |' in markdown


def test_build_summary_reports_missing_and_invalid_junit(
    tmp_path: Path,
) -> None:
    invalid = tmp_path / 'invalid.xml'
    invalid.write_text('<testsuites>', encoding='utf-8')

    markdown = ci_summary.build_summary(
        argparse.Namespace(
            title='Broken tests',
            input_markdown=None,
            junit=[
                f"Missing={tmp_path / 'missing.xml'}",
                f'Invalid={invalid}',
            ],
            coverage=None,
        )
    )

    assert '**Result:** failed' in markdown
    assert '**Missing result files:** `Missing`' in markdown
    assert '**Invalid JUnit XML for `Invalid`:**' in markdown


def test_build_summary_reports_lowest_lambda_coverage(
    tmp_path: Path,
) -> None:
    coverage = tmp_path / 'coverage.xml'
    coverage.write_text(
        """<?xml version="1.0" ?>
<coverage line-rate="0.75" lines-covered="3" lines-valid="4">
  <packages>
    <package name="forge">
      <classes>
        <class filename="/workspace/modules/foo/lambda/handler.py">
          <lines>
            <line number="1" hits="1" />
            <line number="2" hits="0" />
          </lines>
        </class>
        <class filename="/workspace/modules/foo/main.py">
          <lines>
            <line number="1" hits="0" />
          </lines>
        </class>
      </classes>
    </package>
  </packages>
</coverage>
""",
        encoding='utf-8',
    )

    markdown = ci_summary.build_summary(
        argparse.Namespace(
            title='Coverage tests',
            input_markdown=None,
            junit=[],
            coverage=str(coverage),
        )
    )

    assert '**Coverage:** 75.00% (3/4 lines)' in markdown
    assert '| `modules/foo/lambda/handler.py` | 50.00% | 1 |' in markdown
    assert 'modules/foo/main.py' not in markdown


def test_upsert_pr_comment_updates_existing_marker(
    monkeypatch, tmp_path: Path
) -> None:
    event = tmp_path / 'event.json'
    event.write_text(json.dumps(
        {'pull_request': {'number': 437}}), encoding='utf-8')

    monkeypatch.setenv('GITHUB_EVENT_PATH', str(event))
    monkeypatch.setenv('GITHUB_TOKEN', 'token')
    monkeypatch.setenv('GITHUB_REPOSITORY', 'cisco-open/forge')
    monkeypatch.setenv('GITHUB_API_URL', 'https://api.github.test')

    calls = []

    class Response:
        headers = {'Link': None}

        def __init__(self, payload):
            self.payload = payload

        def __enter__(self):
            return self

        def __exit__(self, *_args):
            return None

        def read(self):
            return json.dumps(self.payload).encode('utf-8')

    def fake_urlopen(request, timeout):
        calls.append((request.get_method(), request.full_url, request.data))
        if request.get_method() == 'GET':
            return Response([{'id': 123, 'body': '<!-- forge-ci-summary:test -->\nold'}])
        if request.get_method() == 'PATCH':
            return Response({})
        raise AssertionError(f"unexpected method {request.get_method()}")

    monkeypatch.setattr(ci_summary.urllib.request, 'urlopen', fake_urlopen)

    ci_summary.upsert_pr_comment('forge-ci-summary:test', '## Updated\n')

    assert [call[0] for call in calls] == ['GET', 'PATCH']
    assert calls[1][1] == 'https://api.github.test/repos/cisco-open/forge/issues/comments/123'
    assert b'## Updated' in calls[1][2]


def test_upsert_pr_comment_creates_marker_when_missing(
    monkeypatch, tmp_path: Path
) -> None:
    event = tmp_path / 'event.json'
    event.write_text(json.dumps(
        {'pull_request': {'number': 437}}), encoding='utf-8')

    monkeypatch.setenv('GITHUB_EVENT_PATH', str(event))
    monkeypatch.setenv('GITHUB_TOKEN', 'token')
    monkeypatch.setenv('GITHUB_REPOSITORY', 'cisco-open/forge')
    monkeypatch.setenv('GITHUB_API_URL', 'https://api.github.test')

    calls = []

    class Response:
        headers = {'Link': None}

        def __init__(self, payload):
            self.payload = payload

        def __enter__(self):
            return self

        def __exit__(self, *_args):
            return None

        def read(self):
            return json.dumps(self.payload).encode('utf-8')

    def fake_urlopen(request, timeout):
        calls.append((request.get_method(), request.full_url, request.data))
        if request.get_method() == 'GET':
            return Response([])
        if request.get_method() == 'POST':
            return Response({})
        raise AssertionError(f"unexpected method {request.get_method()}")

    monkeypatch.setattr(ci_summary.urllib.request, 'urlopen', fake_urlopen)

    ci_summary.upsert_pr_comment('forge-ci-summary:test', '## Created\n')

    assert [call[0] for call in calls] == ['GET', 'POST']
    assert calls[1][1] == 'https://api.github.test/repos/cisco-open/forge/issues/437/comments'
    assert b'<!-- forge-ci-summary:test -->' in calls[1][2]
    assert b'## Created' in calls[1][2]
