"""Exercise the EC2NodeClass provisioner without a Kubernetes cluster."""

from __future__ import annotations

import json
import os
import re
import subprocess
from pathlib import Path

import pytest

pytestmark = pytest.mark.contract

REPO_ROOT = Path(__file__).resolve().parents[2]
MANIFEST = '''apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: karpenter
spec:
  amiSelectorTerms:
    - id: ami-new
  tags:
    Literal: '$HOME "quoted" $(exit 99)'
'''


@pytest.mark.parametrize('exit_code', [0, 17])
def test_node_class_update_only_applies_and_propagates_errors(
    tmp_path: Path, exit_code: int,
) -> None:
    terraform = (REPO_ROOT / 'modules/infra/eks/karpenter.tf').read_text()
    resource = terraform.split(
        'resource "null_resource" "apply_ec2_node_class" {', 1,
    )[1]
    command = re.search(r'command\s*=\s*<<EOF\n(.*?)\nEOF', resource, re.S)
    assert command is not None
    script = command.group(1)
    for name, value in {
        'var.cluster_name': 'test-cluster',
        'var.aws_profile': 'test-profile',
        'var.aws_region': 'eu-west-1',
        'local.ec2_node_class_manifest': MANIFEST.rstrip(),
    }.items():
        script = script.replace('${' + name + '}', value)

    kubectl = tmp_path / 'kubectl'
    kubectl.write_text('''#!/usr/bin/env python3
import json
import os
import sys
from pathlib import Path

with Path(os.environ['CALL_LOG']).open('a') as log:
    log.write(json.dumps(sys.argv[1:]) + '\\n')
Path(os.environ['MANIFEST_LOG']).write_text(sys.stdin.read())
sys.exit(int(os.environ['EXIT_CODE']))
''')
    kubectl.chmod(0o755)
    call_log = tmp_path / 'call.json'
    manifest_log = tmp_path / 'manifest.yaml'
    result = subprocess.run(
        ['bash', '-c', script],
        env={
            **os.environ,
            'PATH': f'{tmp_path}:{os.environ["PATH"]}',
            'CALL_LOG': str(call_log),
            'MANIFEST_LOG': str(manifest_log),
            'EXIT_CODE': str(exit_code),
        },
        capture_output=True,
        text=True,
        timeout=5,
        check=False,
    )

    assert result.returncode == exit_code, result.stderr
    assert [json.loads(line) for line in call_log.read_text().splitlines()] == [[
        '--context', 'test-cluster-test-profile-eu-west-1',
        '--request-timeout=60s', 'apply', '-f', '-',
    ]]
    assert manifest_log.read_text() == MANIFEST
