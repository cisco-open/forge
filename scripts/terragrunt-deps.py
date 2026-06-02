#!/usr/bin/env python3.12
"""Print child dependencies from `terragrunt list -T --dag` tree output."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

BRANCH_MARKERS = ('├──', '└──', '╰──', '+--', '`--', '\\--')


class DagError(Exception):
    """Raised when the requested DAG path cannot be resolved."""


def normalize_path(path: str) -> str:
    normalized = path.strip().rstrip('/')
    while normalized.startswith('./'):
        normalized = normalized[2:]
    return normalized


def parse_tree_line(line: str) -> tuple[int, str] | None:
    for marker in BRANCH_MARKERS:
        marker_at = line.find(marker)
        if marker_at == -1:
            continue

        path = line[marker_at + len(marker):].strip()
        if not path:
            return None

        prefix = line[:marker_at].replace('\t', '    ')
        return len(prefix) // 4, path

    return None


def append_unique(items: list[str], item: str) -> None:
    if item not in items:
        items.append(item)


class TerragruntDag:
    def __init__(self) -> None:
        self.children: dict[str, list[str]] = defaultdict(list)
        self.original_paths: dict[str, str] = {}

    @classmethod
    def from_lines(cls, lines: list[str]) -> TerragruntDag:
        dag = cls()
        stack: list[str] = []

        for line in lines:
            parsed = parse_tree_line(line)
            if parsed is None:
                continue

            depth, path = parsed
            key = normalize_path(path)
            if not key:
                continue

            dag.original_paths.setdefault(key, path)
            dag.children.setdefault(key, [])

            if depth > len(stack):
                raise DagError(
                    f"cannot parse tree line with skipped depth: {line}")

            stack = stack[:depth]
            if depth > 0:
                append_unique(dag.children[stack[depth - 1]], key)

            stack.append(key)

        return dag

    def resolve(self, path: str) -> str:
        target = normalize_path(path)
        if target in self.original_paths:
            return target

        suffix_matches = [
            key for key in self.original_paths
            if key.endswith(f"/{target}") or target.endswith(f"/{key}")
        ]

        if not suffix_matches:
            raise DagError(f"path not found in DAG: {path}")
        if len(suffix_matches) > 1:
            matches = '\n'.join(
                f"  {self.original_paths[key]}" for key in suffix_matches
            )
            raise DagError(f"path is ambiguous: {path}\nMatches:\n{matches}")

        return suffix_matches[0]


def read_dag_file(path: str) -> list[str]:
    if path == '-':
        return sys.stdin.read().splitlines()

    return Path(path).read_text(encoding='utf-8').splitlines()


def run_terragrunt_list(terragrunt_bin: str, working_dir: str | None) -> list[str]:
    command = [terragrunt_bin, 'list', '-T', '--dag']
    if working_dir:
        command.extend(['--working-dir', working_dir])

    result = subprocess.run(
        command,
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    if result.returncode != 0:
        if result.stderr:
            sys.stderr.write(result.stderr)
        raise DagError(f"terragrunt exited with status {result.returncode}")

    return result.stdout.splitlines()


def collect_paths(dag: TerragruntDag, root: str, transitive: bool) -> list[str]:
    paths: list[str] = []
    seen: set[str] = set()

    def visit(parent: str) -> None:
        for child in dag.children[parent]:
            if child in seen:
                continue
            seen.add(child)
            paths.append(dag.original_paths[child])
            if transitive:
                visit(child)

    visit(root)
    return paths


def format_tree(
    dag: TerragruntDag,
    root: str,
    *,
    include_root: bool,
    transitive: bool,
) -> list[str]:
    lines: list[str] = []
    active: set[str] = set()

    if include_root:
        lines.append(dag.original_paths[root])

    def visit(parent: str, prefix: str) -> None:
        if parent in active:
            lines.append(f"{prefix}╰── [cycle] {dag.original_paths[parent]}")
            return

        active.add(parent)
        children = dag.children[parent]
        for index, child in enumerate(children):
            is_last = index == len(children) - 1
            branch = '╰──' if is_last else '├──'
            lines.append(f"{prefix}{branch} {dag.original_paths[child]}")

            if transitive and dag.children[child]:
                child_prefix = '    ' if is_last else '│   '
                visit(child, f"{prefix}{child_prefix}")

        active.remove(parent)

    visit(root, '')
    return lines


def format_json(path: str, deps: list[str], *, transitive: bool) -> str:
    return json.dumps(
        {
            'path': path,
            'deps': deps,
            'transitive': transitive,
        },
        indent=2,
    )


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            'Print child dependencies for a path from '
            '`terragrunt list -T --dag` output.'
        )
    )
    parser.add_argument('path', help='Terragrunt path to look up in the DAG')
    parser.add_argument(
        '-f',
        '--dag-file',
        help="Read saved DAG output from a file. Use '-' to read stdin.",
    )
    parser.add_argument(
        '-w',
        '--working-dir',
        help='Stack root to pass to terragrunt when --dag-file is not used.',
    )
    parser.add_argument(
        '--terragrunt-bin',
        default='terragrunt',
        help='Terragrunt executable to run when --dag-file is not used.',
    )
    parser.add_argument(
        '--transitive',
        action='store_true',
        help='Include nested child dependencies, not only direct children.',
    )
    parser.add_argument(
        '--include-root',
        action='store_true',
        help='Print the requested path before its child dependencies.',
    )
    parser.add_argument(
        '--format',
        choices=('json', 'paths', 'tree'),
        default='json',
        help='Output format. Defaults to json.',
    )
    parser.add_argument(
        '--paths-only',
        action='store_true',
        help='Deprecated alias for --format paths.',
    )
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)

    try:
        if args.dag_file:
            dag_lines = read_dag_file(args.dag_file)
        else:
            dag_lines = run_terragrunt_list(
                args.terragrunt_bin, args.working_dir)

        dag = TerragruntDag.from_lines(dag_lines)
        root = dag.resolve(args.path)

        output_format = 'paths' if args.paths_only else args.format
        deps = collect_paths(dag, root, args.transitive)

        if output_format == 'json':
            print(
                format_json(
                    dag.original_paths[root],
                    deps,
                    transitive=args.transitive,
                )
            )
        elif output_format == 'paths':
            if deps:
                print('\n'.join(deps))
        else:
            output = format_tree(
                dag,
                root,
                include_root=args.include_root,
                transitive=args.transitive,
            )
            if output:
                print('\n'.join(output))
    except DagError as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1

    return 0


if __name__ == '__main__':
    raise SystemExit(main(sys.argv[1:]))
