"""Offline contracts for maintenance-node scheduling safeguards."""

from pathlib import Path

import pytest

pytestmark = pytest.mark.contract

REPO_ROOT = Path(__file__).resolve().parents[2]


def test_karpenter_controller_tolerations_remain_key_scoped() -> None:
    source = REPO_ROOT.joinpath(
        'modules',
        'infra',
        'eks',
        'karpenter.tf',
    ).read_text(encoding='utf-8')

    toleration_lines = [
        line.strip()
        for line in source.splitlines()
        if 'tolerations[' in line
    ]

    assert toleration_lines == [
        "--set 'tolerations[0].key'=CriticalAddonsOnly \\",
        "--set 'tolerations[0].operator'=Exists \\",
        "--set 'tolerations[1].key'=karpenter.sh/controller \\",
        "--set 'tolerations[1].operator'=Exists \\",
        "--set 'tolerations[1].effect'=NoSchedule \\",
    ]
