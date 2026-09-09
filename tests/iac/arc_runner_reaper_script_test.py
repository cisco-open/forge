import os
import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
REAPER = REPO_ROOT / 'modules/infra/eks/templates/runner_reaper.sh'

FAKE_KUBECTL = '''#!/usr/bin/env python3
import os
import sys
from pathlib import Path


args = sys.argv[1:]
verb = next((arg for arg in args if arg in {'delete', 'exec', 'get'}), '')
calls_file = Path(os.environ['FAKE_CALLS_FILE'])

if os.environ.get('FAKE_REQUIRE_IN_CLUSTER') == 'true':
    kubeconfig = Path(os.environ['KUBECONFIG']).read_text(encoding='utf-8')
    service_account_dir = os.environ['RUNNER_REAPER_SERVICE_ACCOUNT_DIR']
    if (
        'server: "https://192.0.2.10:443"' not in kubeconfig
        or f'tokenFile: {service_account_dir}/token' not in kubeconfig
    ):
        sys.exit(3)

with calls_file.open('a', encoding='utf-8') as calls:
    calls.write(verb + '\\n')

if verb == 'get' and any('autoscalingrunnersets.actions.github.com' in arg for arg in args):
    print(os.environ.get('FAKE_SCOPES', ''))
elif verb == 'get' and '--selector' in args:
    namespace = args[args.index('--namespace') + 1]
    namespace_key = namespace.upper().replace('-', '_')
    print(os.environ.get(f'FAKE_LIST_{namespace_key}', os.environ.get('FAKE_LIST', '')))
elif verb == 'get':
    counter_file = Path(os.environ['FAKE_COUNTER_FILE'])
    counter = int(counter_file.read_text(encoding='utf-8')) if counter_file.exists() else 0
    assignments = os.environ.get('FAKE_ASSIGNMENTS', 'Running|job-123').split(',')
    print(assignments[min(counter, len(assignments) - 1)])
    counter_file.write_text(str(counter + 1), encoding='utf-8')
elif verb == 'exec':
    print(os.environ.get('FAKE_PROBE_RESULT', 'stale:901'))
elif verb == 'delete':
    print('ephemeralrunner.actions.github.com/runner-zombie deleted')
else:
    sys.exit(2)
'''


def run_reaper(
    tmp_path: Path,
    *,
    dry_run: bool,
    assignments: str = 'Running|job-123',
    candidate_list: str = 'runner-zombie|job-123|2020-01-01T00:00:00Z',
    candidate_lists: dict[str, str] | None = None,
    scopes: str = 'tenant-a|pool-a',
    max_probes: int = 50,
    max_probes_per_namespace: int = 50,
    max_deletions_per_namespace: int = 1,
    max_deletions: int = 20,
    in_cluster: bool = False,
) -> tuple[subprocess.CompletedProcess[str], list[str]]:
    bin_dir = tmp_path / 'bin'
    bin_dir.mkdir()
    fake_kubectl = bin_dir / 'kubectl'
    fake_kubectl.write_text(FAKE_KUBECTL, encoding='utf-8')
    fake_kubectl.chmod(0o755)

    calls_file = tmp_path / 'calls'
    env = {
        **os.environ,
        'PATH': f'{bin_dir}:{os.environ["PATH"]}',
        'CLUSTER_NAME': 'test-cluster',
        'DRY_RUN': str(dry_run).lower(),
        'STALE_AFTER_SECONDS': '900',
        'CONFIRMATION_DELAY_SECONDS': '0',
        'MAX_PROBES_PER_NAMESPACE': str(max_probes_per_namespace),
        'MAX_PROBES_PER_RUN': str(max_probes),
        'MAX_DELETIONS_PER_NAMESPACE': str(max_deletions_per_namespace),
        'MAX_DELETIONS_PER_RUN': str(max_deletions),
        'FAKE_CALLS_FILE': str(calls_file),
        'FAKE_COUNTER_FILE': str(tmp_path / 'counter'),
        'FAKE_SCOPES': scopes,
        'FAKE_LIST': candidate_list,
        'FAKE_ASSIGNMENTS': assignments,
        'FAKE_PROBE_RESULT': 'stale:901',
    }
    for namespace, namespace_candidate_list in (candidate_lists or {}).items():
        namespace_key = namespace.upper().replace('-', '_')
        env[f'FAKE_LIST_{namespace_key}'] = namespace_candidate_list
    if in_cluster:
        service_account_dir = tmp_path / 'service-account'
        service_account_dir.mkdir()
        (service_account_dir / 'ca.crt').write_text('test-ca', encoding='utf-8')
        (service_account_dir / 'token').write_text('test-token', encoding='utf-8')
        env.update(
            {
                'FAKE_REQUIRE_IN_CLUSTER': 'true',
                'KUBERNETES_SERVICE_HOST': '192.0.2.10',
                'KUBERNETES_SERVICE_PORT_HTTPS': '443',
                'RUNNER_REAPER_SERVICE_ACCOUNT_DIR': str(service_account_dir),
            }
        )
    result = subprocess.run(
        ['/bin/sh', str(REAPER)],
        check=False,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        timeout=10,
    )
    calls = calls_file.read_text(encoding='utf-8').splitlines()
    return result, calls


def test_dry_run_observes_but_cannot_delete(tmp_path: Path) -> None:
    result, calls = run_reaper(tmp_path, dry_run=True)

    assert result.returncode == 0, result.stderr
    assert 'result=would-delete' in result.stdout
    assert 'delete' not in calls


def test_active_mode_deletes_after_two_matching_checks(tmp_path: Path) -> None:
    result, calls = run_reaper(tmp_path, dry_run=False)

    assert result.returncode == 0, result.stderr
    assert 'result=deleted' in result.stdout
    assert calls.count('exec') == 2
    assert calls.count('delete') == 1


def test_changed_job_id_fails_closed_on_second_check(tmp_path: Path) -> None:
    result, calls = run_reaper(
        tmp_path,
        dry_run=False,
        assignments='Running|job-123,Running|job-456',
    )

    assert result.returncode == 0, result.stderr
    assert 'reason=second-check-not-stale' in result.stdout
    assert calls.count('exec') == 1
    assert 'delete' not in calls


def test_young_runner_is_not_probed(tmp_path: Path) -> None:
    result, calls = run_reaper(
        tmp_path,
        dry_run=False,
        candidate_list='runner-young|job-123|2999-01-01T00:00:00Z',
    )

    assert result.returncode == 0, result.stderr
    assert 'candidates=0 probes=0 actions=0' in result.stdout
    assert 'exec' not in calls
    assert 'delete' not in calls


def test_probe_cap_bounds_first_pass_execs(tmp_path: Path) -> None:
    result, calls = run_reaper(
        tmp_path,
        dry_run=True,
        candidate_list=(
            'runner-oldest|job-123|2020-01-01T00:00:00Z\n'
            'runner-newer|job-456|2021-01-01T00:00:00Z'
        ),
        max_probes=1,
    )

    assert result.returncode == 0, result.stderr
    assert 'result=probe-limit-reached max_probes_per_run=1' in result.stdout
    assert 'candidates=1 probes=1 actions=1' in result.stdout
    assert calls.count('exec') == 2
    assert 'delete' not in calls


def test_all_discovered_tenants_are_covered_with_per_tenant_limits(tmp_path: Path) -> None:
    result, calls = run_reaper(
        tmp_path,
        dry_run=False,
        scopes='tenant-a|pool-a\ntenant-b|pool-b',
        candidate_lists={
            'tenant-a': (
                'runner-a-oldest|job-123|2020-01-01T00:00:00Z\n'
                'runner-a-newer|job-123|2021-01-01T00:00:00Z'
            ),
            'tenant-b': 'runner-b|job-123|2020-01-01T00:00:00Z',
        },
        max_deletions_per_namespace=1,
    )

    assert result.returncode == 0, result.stderr
    assert 'namespace=tenant-a runner=runner-a-oldest' in result.stdout
    assert 'namespace=tenant-b runner=runner-b' in result.stdout
    assert 'tenants=2 scale_sets=2 candidates=3 probes=3 actions=2' in result.stdout
    assert calls.count('delete') == 2


def test_in_cluster_kubeconfig_uses_mounted_token_file(tmp_path: Path) -> None:
    result, calls = run_reaper(tmp_path, dry_run=True, in_cluster=True)

    assert result.returncode == 0, result.stderr
    assert 'result=would-delete' in result.stdout
    assert calls.count('exec') == 2
    assert 'test-token' not in result.stdout
    assert 'test-token' not in result.stderr
