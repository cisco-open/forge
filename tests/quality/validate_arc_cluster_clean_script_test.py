import os
import subprocess
import textwrap
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT = REPO_ROOT / 'scripts' / 'validate-arc-cluster-clean.sh'


def write_executable(path: Path, source: str) -> None:
    path.write_text(textwrap.dedent(source), encoding='utf-8')
    path.chmod(0o755)


def make_fixture(tmp_path: Path) -> tuple[Path, dict[str, str]]:
    tenants_dir = tmp_path / 'tenants'
    tenant_dir = tenants_dir / 'tenant-a'
    tenant_dir.mkdir(parents=True)
    (tenant_dir / 'config.yml').write_text(
        'arc_runner_specs:\n  linux:\n    volume_requests_storage_type: gp3\n',
        encoding='utf-8',
    )

    bin_dir = tmp_path / 'bin'
    bin_dir.mkdir()
    write_executable(
        bin_dir / 'aws',
        '''\
        #!/usr/bin/env python3
        import json
        import os
        import sys

        args = sys.argv[1:]
        if args[:2] == ['sts', 'get-caller-identity']:
            print(os.environ.get('STUB_ACCOUNT', '123456789012'))
        elif args[:2] == ['eks', 'describe-cluster']:
            if os.environ.get('STUB_CLUSTER_MISSING') == '1':
                print(
                    'ResourceNotFoundException: No cluster found for name: '
                    'forge-test-blue',
                    file=sys.stderr,
                )
                raise SystemExit(254)
            if os.environ.get('STUB_CLUSTER_ERROR') == '1':
                print('AccessDeniedException: denied', file=sys.stderr)
                raise SystemExit(254)
            print('ACTIVE')
        elif args[:2] == ['eks', 'update-kubeconfig']:
            pass
        elif args[:2] == ['eks', 'list-pod-identity-associations']:
            associations = (
                [{'associationId': 'assoc-1', 'serviceAccount': 'tenant-a-test-linux'}]
                if os.environ.get('STUB_POD_IDENTITY') == '1'
                else []
            )
            print(json.dumps({'associations': associations}))
        else:
            raise SystemExit(f'unexpected aws arguments: {args}')
        ''',
    )
    write_executable(
        bin_dir / 'kubectl',
        '''\
        #!/usr/bin/env python3
        import json
        import os
        import sys

        args = sys.argv[1:]
        if 'get' in args and any(value.startswith('--raw=') for value in args):
            print('ok')
        elif 'get' in args:
            target = args[args.index('get') + 1]
            if target == 'namespace':
                print(
                    'namespace/tenant-a'
                    if os.environ.get('STUB_NAMESPACE') == '1'
                    else ''
                )
            elif target.startswith('nodepool'):
                print(
                    'nodepool.karpenter.sh/karpenter-tenant-a'
                    if os.environ.get('STUB_NODE_POOL') == '1'
                    else ''
                )
            elif target.startswith('ec2nodeclass'):
                print('')
            else:
                raise SystemExit(f'unexpected kubectl target: {target}')
        else:
            raise SystemExit(f'unexpected kubectl arguments: {args}')
        ''',
    )

    env = os.environ.copy()
    env['PATH'] = f'{bin_dir}:{env["PATH"]}'
    return tenants_dir, env


def run_script(
    tenants_dir: Path,
    env: dict[str, str],
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [
            'bash',
            str(SCRIPT),
            '--tenants-dir',
            str(tenants_dir),
            '--cluster',
            'forge-test-blue',
            '--aws-profile',
            'test-profile',
            '--aws-region',
            'us-east-1',
            '--expected-account-id',
            '123456789012',
        ],
        check=False,
        capture_output=True,
        env=env,
        text=True,
        timeout=10,
    )


def test_clean_cluster_passes_pre_destroy_gate(tmp_path: Path) -> None:
    tenants_dir, env = make_fixture(tmp_path)

    result = run_script(tenants_dir, env)

    assert result.returncode == 0, result.stderr
    assert "Checking tenant 'tenant-a' on 'forge-test-blue'" in result.stdout
    assert 'has no live tenant ARC footprint' in result.stdout


def test_live_namespace_blocks_destroy(tmp_path: Path) -> None:
    tenants_dir, env = make_fixture(tmp_path)
    env['STUB_NAMESPACE'] = '1'

    result = run_script(tenants_dir, env)

    assert result.returncode != 0
    assert "namespace 'tenant-a'" in result.stderr


def test_karpenter_and_aws_remnants_block_destroy(tmp_path: Path) -> None:
    tenants_dir, env = make_fixture(tmp_path)
    env.update({
        'STUB_NODE_POOL': '1',
        'STUB_POD_IDENTITY': '1',
    })

    result = run_script(tenants_dir, env)

    assert result.returncode != 0
    assert 'NodePool' in result.stderr
    assert 'Pod Identity associations remain' in result.stderr


def test_wrong_account_stops_pre_destroy_inspection(tmp_path: Path) -> None:
    tenants_dir, env = make_fixture(tmp_path)
    env['STUB_ACCOUNT'] = '999999999999'

    result = run_script(tenants_dir, env)

    assert result.returncode != 0
    assert 'AWS account mismatch' in result.stderr


def test_missing_cluster_is_already_clean(tmp_path: Path) -> None:
    tenants_dir, env = make_fixture(tmp_path)
    env['STUB_CLUSTER_MISSING'] = '1'
    env['STUB_NAMESPACE'] = '1'

    result = run_script(tenants_dir, env)

    assert result.returncode == 0, result.stderr
    assert "cluster 'forge-test-blue' is already absent" in result.stdout
    assert "Checking tenant 'tenant-a'" not in result.stdout


def test_cluster_lookup_error_stops_pre_destroy_inspection(
    tmp_path: Path,
) -> None:
    tenants_dir, env = make_fixture(tmp_path)
    env['STUB_CLUSTER_ERROR'] = '1'

    result = run_script(tenants_dir, env)

    assert result.returncode != 0
    assert 'unable to inspect EKS cluster' in result.stderr
    assert 'AccessDeniedException' in result.stderr


def test_tenant_without_scale_sets_is_still_checked(tmp_path: Path) -> None:
    tenants_dir, env = make_fixture(tmp_path)
    (tenants_dir / 'tenant-a' / 'config.yml').write_text(
        'arc_runner_specs: {}\n', encoding='utf-8'
    )
    env['STUB_NAMESPACE'] = '1'

    result = run_script(tenants_dir, env)

    assert result.returncode != 0
    assert "namespace 'tenant-a'" in result.stderr
