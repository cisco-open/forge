#!/usr/bin/env python3.12
"""Return direct Terragrunt DAG dependents as JSON."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

BRANCH_MARKERS = ('├──', '└──', '╰──', '+--', '`--', '\\--')


def normalize(path: str) -> str:
    path = path.strip().rstrip('/')
    while path.startswith('./'):
        path = path[2:]
    return path


def parse_tree_line(line: str) -> tuple[int, str] | None:
    for marker in BRANCH_MARKERS:
        marker_index = line.find(marker)
        if marker_index == -1:
            continue

        prefix = line[:marker_index].replace('\t', '    ')
        path = line[marker_index + len(marker):].strip()
        return len(prefix) // 4, path

    return None


def read_dag(args: argparse.Namespace) -> list[str]:
    if args.dag_file:
        if args.dag_file == '-':
            return sys.stdin.read().splitlines()
        return Path(args.dag_file).read_text(encoding='utf-8').splitlines()

    command = [args.terragrunt_bin, 'list', '-T', '--dag']
    if args.working_dir:
        command.extend(['--working-dir', args.working_dir])

    result = subprocess.run(
        command,
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    if result.returncode != 0:
        if result.stderr:
            print(result.stderr, end='', file=sys.stderr)
        raise RuntimeError(f'terragrunt exited with {result.returncode}')

    return result.stdout.splitlines()


def build_dependency_map(
    lines: list[str],
) -> tuple[dict[str, list[str]], dict[str, str]]:
    children: dict[str, list[str]] = {}
    original_paths: dict[str, str] = {}
    stack: list[str] = []

    for line in lines:
        parsed = parse_tree_line(line)
        if parsed is None:
            continue

        depth, original_path = parsed
        path = normalize(original_path)
        if not path:
            continue
        if depth > len(stack):
            raise RuntimeError(f'cannot parse DAG line: {line}')

        children.setdefault(path, [])
        original_paths.setdefault(path, original_path)

        stack = stack[:depth]
        if depth > 0 and path not in children[stack[-1]]:
            children[stack[-1]].append(path)
        stack.append(path)

    return children, original_paths


def resolve_path(path: str, original_paths: dict[str, str]) -> str:
    target = normalize(path)
    if target in original_paths:
        return target

    matches = [
        candidate for candidate in original_paths
        if candidate.endswith(f'/{target}') or target.endswith(f'/{candidate}')
    ]
    if not matches:
        raise RuntimeError(f'path not found in DAG: {path}')
    if len(matches) > 1:
        joined = '\n'.join(f'  {original_paths[match]}' for match in matches)
        raise RuntimeError(f'path is ambiguous: {path}\nMatches:\n{joined}')

    return matches[0]


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description='Return direct Terragrunt DAG dependents as JSON.'
    )
    parser.add_argument('path', help='Terragrunt path to look up')
    parser.add_argument(
        '-f',
        '--dag-file',
        help="Read saved DAG output from a file. Use '-' for stdin.",
    )
    parser.add_argument(
        '-w',
        '--working-dir',
        help='Terragrunt stack root when --dag-file is not used.',
    )
    parser.add_argument(
        '--terragrunt-bin',
        default='terragrunt',
        help='Terragrunt executable to run.',
    )
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)

    try:
        children, original_paths = build_dependency_map(read_dag(args))
        path = resolve_path(args.path, original_paths)
        deps = [original_paths[dep] for dep in children.get(path, [])]
        print(
            json.dumps(
                {'path': original_paths[path], 'deps': deps},
                indent=2,
            )
        )
    except RuntimeError as error:
        print(f'Error: {error}', file=sys.stderr)
        return 1

    return 0


if __name__ == '__main__':
    raise SystemExit(main(sys.argv[1:]))
