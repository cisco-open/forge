import json
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT_PATH = REPO_ROOT / 'scripts' / 'terragrunt-deps.py'


def run_script(dag_file: Path, path: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [
            sys.executable,
            str(SCRIPT_PATH),
            path,
            '--dag-file',
            str(dag_file),
        ],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )


def test_terragrunt_deps_returns_direct_dependents_from_saved_dag(
    tmp_path: Path,
) -> None:
    dag_file = tmp_path / 'dag.txt'
    dag_file.write_text(
        '\n'.join(
            [
                '├── live/network',
                '│   ├── live/network/vpc',
                '│   └── live/network/iam',
                '└── live/apps',
                '    └── live/apps/service',
            ]
        ),
        encoding='utf-8',
    )

    result = run_script(dag_file, 'live/network')

    assert result.returncode == 0
    assert result.stderr == ''
    assert json.loads(result.stdout) == {
        'path': 'live/network',
        'deps': [
            'live/network/vpc',
            'live/network/iam',
        ],
    }


def test_terragrunt_deps_rejects_ambiguous_suffix_match(
    tmp_path: Path,
) -> None:
    dag_file = tmp_path / 'dag.txt'
    dag_file.write_text(
        '\n'.join(
            [
                '├── prod/app',
                '└── dev/app',
            ]
        ),
        encoding='utf-8',
    )

    result = run_script(dag_file, 'app')

    assert result.returncode == 1
    assert result.stdout == ''
    assert 'Error: path is ambiguous: app' in result.stderr
    assert 'prod/app' in result.stderr
    assert 'dev/app' in result.stderr


def test_terragrunt_deps_reports_missing_path(tmp_path: Path) -> None:
    dag_file = tmp_path / 'dag.txt'
    dag_file.write_text(
        '\n'.join(
            [
                '└── live/apps',
                '    └── live/apps/service',
            ]
        ),
        encoding='utf-8',
    )

    result = run_script(dag_file, 'live/network')

    assert result.returncode == 1
    assert result.stdout == ''
    assert 'Error: path not found in DAG: live/network' in result.stderr
