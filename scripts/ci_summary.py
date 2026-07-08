"""Write deterministic CI test summaries for GitHub Actions.

The workflows use this after test commands emit result files. It writes the same
Markdown to the job summary, to a local summary file, and to a sticky PR comment
identified by a hidden marker.
"""

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class JunitSummary:
    label: str
    tests: int = 0
    failures: int = 0
    errors: int = 0
    skipped: int = 0
    duration: float = 0.0
    missing: bool = False
    parse_error: str | None = None

    @property
    def passed(self) -> int:
        return self.tests - self.failures - self.errors - self.skipped

    @property
    def result(self) -> str:
        if self.missing:
            return 'missing'
        if self.parse_error:
            return 'invalid'
        if self.failures or self.errors:
            return 'failed'
        return 'passed'


def md_escape(value: str) -> str:
    return value.replace('|', '\\|').replace('\n', ' ')


def parse_junit_arg(value: str) -> tuple[str, Path]:
    if '=' in value:
        label, path = value.split('=', 1)
        return label.strip() or Path(path).stem, Path(path)
    path = Path(value)
    return path.stem, path


def summarize_junit(label: str, path: Path) -> JunitSummary:
    if not path.exists():
        return JunitSummary(label=label, missing=True)

    try:
        root = ET.parse(path).getroot()
    except ET.ParseError as exc:
        return JunitSummary(label=label, parse_error=str(exc))

    suites = list(root.iter('testsuite'))
    if not suites and root.tag == 'testsuite':
        suites = [root]

    return JunitSummary(
        label=label,
        tests=sum(int(suite.get('tests', 0)) for suite in suites),
        failures=sum(int(suite.get('failures', 0)) for suite in suites),
        errors=sum(int(suite.get('errors', 0)) for suite in suites),
        skipped=sum(int(suite.get('skipped', 0)) for suite in suites),
        duration=sum(float(suite.get('time', 0.0)) for suite in suites),
    )


def add_coverage(lines: list[str], coverage_path: Path) -> None:
    if not coverage_path.exists():
        lines.extend(['**Coverage:** coverage.xml was not generated.', ''])
        return

    try:
        root = ET.parse(coverage_path).getroot()
    except ET.ParseError as exc:
        lines.extend(
            [f"**Coverage:** coverage.xml is invalid: `{md_escape(str(exc))}`", ''])
        return

    line_rate = float(root.get('line-rate', 0.0)) * 100
    lines_covered = int(root.get('lines-covered', 0))
    lines_valid = int(root.get('lines-valid', 0))
    lines.extend(
        [
            f"**Coverage:** {line_rate:.2f}% ({lines_covered}/{lines_valid} lines)",
            '',
            '### Lowest-covered Lambda files',
            '',
            '| File | Coverage | Missed lines |',
            '| --- | ---: | ---: |',
        ]
    )

    files = []
    for class_node in root.findall('.//class'):
        filename = class_node.get('filename', '')
        if '/modules/' in filename:
            display_filename = 'modules/' + filename.split('/modules/', 1)[1]
        else:
            display_filename = filename
        if not display_filename.startswith('modules/') or '/lambda/' not in display_filename:
            continue
        line_nodes = class_node.findall('lines/line')
        valid = len(line_nodes)
        if valid == 0:
            continue
        covered = sum(1 for line in line_nodes if int(line.get('hits', 0)) > 0)
        files.append((covered / valid, valid - covered, display_filename))

    for rate, missed, filename in sorted(files)[:8]:
        lines.append(
            f"| `{md_escape(filename)}` | {rate * 100:.2f}% | {missed} |")
    lines.append('')


def slugify(value: str) -> str:
    return re.sub(r'[^a-z0-9]+', '-', value.lower()).strip('-') or 'test-summary'


def build_summary(args: argparse.Namespace) -> str:
    if args.input_markdown:
        return Path(args.input_markdown).read_text(encoding='utf-8').rstrip() + '\n'

    summaries = [summarize_junit(*parse_junit_arg(value))
                 for value in args.junit]
    result = 'passed'
    if any(summary.result in {'failed', 'invalid'} for summary in summaries):
        result = 'failed'
    elif any(summary.result == 'missing' for summary in summaries):
        result = 'incomplete'

    lines = [f"## {args.title}", '', f"**Result:** {result}", '']
    if summaries:
        lines.extend(
            [
                '| Suite | Passed | Failed | Errors | Skipped | Total | Duration | Result |',
                '| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |',
            ]
        )
        for summary in summaries:
            lines.append(
                '| '
                f"{md_escape(summary.label)} | "
                f"{summary.passed} | "
                f"{summary.failures} | "
                f"{summary.errors} | "
                f"{summary.skipped} | "
                f"{summary.tests} | "
                f"{summary.duration:.2f}s | "
                f"{summary.result} |"
            )
        lines.append('')

    missing = [summary.label for summary in summaries if summary.missing]
    if missing:
        missing_list = ', '.join(f"`{md_escape(label)}`" for label in missing)
        lines.extend(
            [
                f"**Missing result files:** {missing_list}",
                '',
            ]
        )

    parse_errors = [summary for summary in summaries if summary.parse_error]
    for summary in parse_errors:
        lines.extend(
            [
                f"**Invalid JUnit XML for `{md_escape(summary.label)}`:** "
                f"`{md_escape(summary.parse_error or '')}`",
                '',
            ]
        )

    if args.coverage:
        add_coverage(lines, Path(args.coverage))

    return '\n'.join(lines).rstrip() + '\n'


def github_json(method: str, url: str, token: str, data: dict | None = None) -> tuple[object, str | None]:
    body = None if data is None else json.dumps(data).encode('utf-8')
    request = urllib.request.Request(
        url,
        data=body,
        method=method,
        headers={
            'Accept': 'application/vnd.github+json',
            'Authorization': f"Bearer {token}",
            'Content-Type': 'application/json',
            'X-GitHub-Api-Version': '2022-11-28',
        },
    )
    with urllib.request.urlopen(request, timeout=20) as response:
        payload = response.read()
        link = response.headers.get('Link')
    if not payload:
        return {}, link
    return json.loads(payload), link


def next_link(link_header: str | None) -> str | None:
    if not link_header:
        return None
    for part in link_header.split(','):
        if 'rel="next"' not in part:
            continue
        match = re.search(r'<([^>]+)>', part)
        if match:
            return match.group(1)
    return None


def pull_request_number() -> int | None:
    event_path = os.environ.get('GITHUB_EVENT_PATH')
    if not event_path:
        return None
    event = json.loads(Path(event_path).read_text(encoding='utf-8'))
    pull_request = event.get('pull_request') or {}
    number = pull_request.get('number')
    return int(number) if number else None


def upsert_pr_comment(marker: str, markdown: str) -> None:
    token = os.environ.get('GITHUB_TOKEN')
    repository = os.environ.get('GITHUB_REPOSITORY')
    api_url = os.environ.get('GITHUB_API_URL', 'https://api.github.com')
    pr_number = pull_request_number()

    if not token or not repository or pr_number is None:
        print(
            'Skipping PR comment: not running in a pull_request context.', file=sys.stderr)
        return

    marker_line = f"<!-- {marker} -->"
    body = f"{marker_line}\n{markdown}"
    comments_url = f"{api_url}/repos/{repository}/issues/{pr_number}/comments?per_page=100"

    try:
        while comments_url:
            comments, link = github_json('GET', comments_url, token)
            for comment in comments:
                if marker_line not in str(comment.get('body', '')):
                    continue
                github_json(
                    'PATCH',
                    f"{api_url}/repos/{repository}/issues/comments/{comment['id']}",
                    token,
                    {'body': body},
                )
                print(f"Updated PR summary comment for {marker}.")
                return
            comments_url = next_link(link)

        github_json(
            'POST',
            f"{api_url}/repos/{repository}/issues/{pr_number}/comments",
            token,
            {'body': body},
        )
        print(f"Created PR summary comment for {marker}.")
    except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError) as exc:
        print(
            f"Warning: failed to upsert PR summary comment for {marker}: {exc}", file=sys.stderr)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--title', required=True)
    parser.add_argument('--input-markdown')
    parser.add_argument('--junit', action='append', default=[])
    parser.add_argument('--coverage')
    parser.add_argument('--output')
    parser.add_argument('--comment-marker')
    args = parser.parse_args()

    markdown = build_summary(args)
    output_path = Path(args.output or f"{slugify(args.title)}.md")
    output_path.write_text(markdown, encoding='utf-8')

    summary_path = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary_path:
        with Path(summary_path).open('a', encoding='utf-8') as summary_file:
            summary_file.write(markdown)

    if args.comment_marker:
        upsert_pr_comment(args.comment_marker, markdown)


if __name__ == '__main__':
    main()
