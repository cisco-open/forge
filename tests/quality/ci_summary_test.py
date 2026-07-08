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
