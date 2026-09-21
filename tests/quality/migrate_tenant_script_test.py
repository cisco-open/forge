import os
import subprocess
import textwrap
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT = REPO_ROOT / 'scripts' / 'migrate-tenant.sh'


def write_executable(path: Path, source: str) -> None:
    path.write_text(textwrap.dedent(source), encoding='utf-8')
    path.chmod(0o755)


def make_fixture(tmp_path: Path) -> tuple[Path, dict[str, str]]:
    tenant_dir = tmp_path / 'tenant-a'
    tenant_dir.mkdir()
    config = tenant_dir / 'config.yml'
    config.write_text(
        'arc_cluster_name: forge-test-blue\nmigrate_arc_cluster: false\n',
        encoding='utf-8',
    )
    runtime = tmp_path / 'runtime'
    runtime.mkdir()
    (runtime / 'live-blue').touch()
    bin_dir = tmp_path / 'bin'
    bin_dir.mkdir()

    fake_tool = bin_dir / 'fake-tool'
    interpreter = 'python3'
    write_executable(
        fake_tool,
        f'''\
        #!/usr/bin/env {interpreter}
        import json
        import os
        import pathlib
        import re
        import sys

        tool = pathlib.Path(sys.argv[0]).name
        args = sys.argv[1:]
        config_path = pathlib.Path(os.environ['STUB_CONFIG'])
        runtime = pathlib.Path(os.environ['STUB_RUNTIME'])

        def config_values():
            source = config_path.read_text()
            cluster = re.search(r'arc_cluster_name: (.*)', source).group(1)
            migrate = re.search(r'migrate_arc_cluster: (.*)', source).group(1)
            return source, cluster, migrate

        def color(value):
            if 'forge-test-blue' in value:
                return 'blue'
            if 'forge-test-green' in value:
                return 'green'
            raise SystemExit(f'unknown cluster/context: {{value}}')

        def is_live(cluster_color):
            return (runtime / f'live-{{cluster_color}}').exists()

        if tool == 'terragrunt':
            if args and args[0] == 'render':
                _, cluster, _ = config_values()
                runners = {{
                    'linux': {{'scale_set_name': 'linux'}},
                    'dind': {{'scale_set_name': 'dind'}},
                }}
                if os.environ.get('STUB_EMPTY_RUNNERS') == '1':
                    runners = {{}}
                print(json.dumps({{
                    'inputs': {{
                        'aws_profile': 'test-profile',
                        'aws_region': 'us-east-1',
                        'deployment_config': {{
                            'deployment_prefix': 'tenant-a-test',
                            'tenant': {{'name': 'tenant-a'}},
                        }},
                        'arc_deployment_specs': {{
                            'cluster_name': cluster,
                            'runner_specs': runners,
                        }},
                    }},
                }}))
            elif args and args[0] == 'apply':
                _, cluster, migrate = config_values()
                cluster_color = color(cluster)
                target = args[args.index('--target') + 1]
                with (runtime / 'applies').open('a', encoding='utf-8') as log:
                    log.write(f'{{target}},{{cluster}},{{migrate}}\\n')
                if target == 'module.arc_runners':
                    live = runtime / f'live-{{cluster_color}}'
                    if migrate == 'true':
                        if not (
                            cluster_color == 'blue'
                            and os.environ.get('STUB_ORPHAN_SOURCE') == '1'
                        ):
                            live.unlink(missing_ok=True)
                    elif os.environ.get('STUB_EMPTY_RUNNERS') != '1':
                        live.touch()
                else:
                    raise SystemExit(f'unexpected terragrunt target: {{target}}')
            else:
                raise SystemExit(f'unexpected terragrunt arguments: {{args}}')

        elif tool == 'aws':
            if args[:2] == ['sts', 'get-caller-identity']:
                print(os.environ.get('STUB_ACCOUNT', '123456789012'))
            elif args[:2] == ['eks', 'update-kubeconfig']:
                pass
            elif args[:2] == ['eks', 'list-pod-identity-associations']:
                cluster_color = color(args[args.index('--cluster-name') + 1])
                associations = []
                if is_live(cluster_color):
                    associations = [{{'associationId': f'assoc-{{cluster_color}}'}}]
                print(json.dumps({{'associations': associations}}))
            else:
                raise SystemExit(f'unexpected aws arguments: {{args}}')

        elif tool == 'yq':
            expression = args[-2]
            source, cluster, migrate = config_values()
            if expression == '.arc_cluster_name | tag':
                print(os.environ.get('STUB_CLUSTER_TYPE', '!!str'))
            elif expression == '.migrate_arc_cluster | tag':
                print(os.environ.get('STUB_MIGRATE_TYPE', '!!bool'))
            elif expression == '.arc_cluster_name':
                print(cluster)
            elif expression.startswith('.migrate_arc_cluster = '):
                value = expression.rsplit(' ', 1)[-1]
                config_path.write_text(
                    re.sub(r'migrate_arc_cluster: .*', f'migrate_arc_cluster: {{value}}', source),
                    encoding='utf-8',
                )
            elif expression.startswith('.arc_cluster_name = '):
                value = expression.split('=', 1)[1].strip().strip('"')
                config_path.write_text(
                    re.sub(r'arc_cluster_name: .*', f'arc_cluster_name: {{value}}', source),
                    encoding='utf-8',
                )
            else:
                raise SystemExit(f'unexpected yq expression: {{expression}}')

        elif tool == 'kubectl':
            context = args[args.index('--context') + 1]
            cluster_color = color(context)
            live = is_live(cluster_color)
            if 'get' in args and any(arg.startswith('--raw=') for arg in args):
                print('ok')
            elif 'wait' in args:
                if not live:
                    raise SystemExit(1)
            elif 'logs' in args:
                if os.environ.get('STUB_CONFLICT') == '1':
                    print('409 Conflict: already has an active session')
                else:
                    print('Listening for Jobs')
            elif 'patch' in args:
                runner = args[args.index('patch') + 2]
                (runtime / f'patched-{{runner}}').touch()
            elif 'get' in args:
                target = args[args.index('get') + 1]
                if target == 'namespace':
                    namespace_absent = (
                        os.environ.get('STUB_SOURCE_NAMESPACE_ABSENT') == '1'
                        and cluster_color == 'blue'
                    )
                    print('namespace/tenant-a' if live and not namespace_absent else '')
                elif target.startswith('nodepool') or target.startswith('ec2nodeclass'):
                    print('')
                elif target == 'autoscalingrunnersets.actions.github.com':
                    if not live:
                        raise SystemExit(1)
                    names = [] if os.environ.get('STUB_EMPTY_RUNNERS') == '1' else ['dind', 'linux']
                    if os.environ.get('STUB_EXTRA_SOURCE_RUNNER') == '1':
                        names.append('orphan')
                    print(json.dumps({{
                        'items': [{{'metadata': {{'name': name}}}} for name in names],
                    }}))
                elif target == 'autoscalingrunnerset.actions.github.com':
                    runner = args[args.index('get') + 2]
                    if not live:
                        raise SystemExit(1)
                    is_patched = (runtime / f'patched-{{runner}}').exists()
                    print(json.dumps({{
                        'metadata': {{'name': runner}},
                        'spec': {{
                            'minRunners': 0 if is_patched else 1,
                            'maxRunners': 0 if is_patched else 10,
                        }},
                    }}))
                elif target == 'autoscalinglisteners.actions.github.com':
                    if not live:
                        raise SystemExit(1)
                    if '-l' not in args:
                        names = [] if os.environ.get('STUB_EMPTY_RUNNERS') == '1' else ['dind', 'linux']
                        if (
                            os.environ.get('STUB_MISSING_SOURCE_LISTENER') == '1'
                            and 'dind' in names
                        ):
                            names.remove('dind')
                        if os.environ.get('STUB_EXTRA_SOURCE_RUNNER') == '1':
                            names.append('orphan')
                        items = [{{
                            'metadata': {{
                                'name': f'{{name}}-listener',
                                'uid': f'{{name}}-listener-old-uid',
                                'labels': {{'actions.github.com/scale-set-name': name}},
                            }},
                            'spec': {{'maxRunners': 10}},
                        }} for name in names]
                    else:
                        selector = args[args.index('-l') + 1]
                        runner = selector.split('=', 1)[1]
                        checks_file = runtime / f'listener-checks-{{runner}}'
                        checks = int(checks_file.read_text()) + 1 if checks_file.exists() else 1
                        checks_file.write_text(str(checks), encoding='utf-8')
                        is_patched = (runtime / f'patched-{{runner}}').exists()
                        delayed = (
                            os.environ.get('STUB_LISTENER_DELAY') == '1'
                            and checks == 1
                        )
                        at_zero = is_patched and not delayed
                        runner_checks_file = runtime / 'runner-checks'
                        runner_checks = (
                            int(runner_checks_file.read_text())
                            if runner_checks_file.exists()
                            else 0
                        )
                        listener_absent = (
                            os.environ.get('STUB_LISTENER_ABSENT_WHILE_ACTIVE') == '1'
                            and runner == 'dind'
                            and runner_checks < 2
                        )
                        if listener_absent:
                            items = []
                        else:
                            items = [{{
                                'metadata': {{
                                    'name': f'{{runner}}-listener',
                                    'uid': (
                                        f'{{runner}}-listener-zero-uid'
                                        if at_zero
                                        else f'{{runner}}-listener-old-uid'
                                    ),
                                    'labels': {{'actions.github.com/scale-set-name': runner}},
                                }},
                                'spec': {{}} if at_zero else {{'maxRunners': 10}},
                            }}]
                    print(json.dumps({{'items': items}}))
                elif target == 'pod':
                    listener = args[args.index('get') + 2]
                    runner = listener.removesuffix('-listener')
                    if not live or not (runtime / f'patched-{{runner}}').exists():
                        print('')
                    else:
                        print(json.dumps({{
                            'metadata': {{
                                'name': listener,
                                'ownerReferences': [{{
                                    'uid': f'{{runner}}-listener-zero-uid',
                                }}],
                            }},
                            'status': {{
                                'phase': 'Running',
                                'conditions': [{{'type': 'Ready', 'status': 'True'}}],
                                'containerStatuses': [{{'ready': True}}],
                            }},
                        }}))
                elif target == 'ephemeralrunners.actions.github.com':
                    active_job = os.environ.get('STUB_ACTIVE_JOB') == '1' and live
                    if active_job and not all(
                        (runtime / f'patched-{{name}}').exists()
                        for name in ('dind', 'linux')
                    ):
                        raise SystemExit('all scale sets must be patched first')
                    checks_file = runtime / 'runner-checks'
                    checks = int(checks_file.read_text()) if checks_file.exists() else 0
                    selected_runner = None
                    if '-l' in args:
                        selected_runner = args[args.index('-l') + 1].split('=', 1)[1]
                        if selected_runner == 'dind':
                            checks += 1
                            checks_file.write_text(str(checks), encoding='utf-8')
                    has_runner = active_job and checks < 2 and selected_runner in (None, 'dind')
                    items = []
                    if has_runner:
                        items.append({{
                            'metadata': {{
                                'name': 'dind-runner-active',
                                'labels': {{'actions.github.com/scale-set-name': 'dind'}},
                            }},
                        }})
                    print(json.dumps({{'items': items}}))
                elif target == 'ephemeralrunnersets.actions.github.com':
                    print(json.dumps({{
                        'items': [{{
                            'spec': {{'replicas': 0}},
                            'status': {{
                                'currentReplicas': 0,
                                'pendingEphemeralRunners': 0,
                                'runningEphemeralRunners': 0,
                            }},
                        }}],
                    }}))
                elif target == 'pods':
                    if '-l' not in args:
                        checks_file = runtime / 'runner-checks'
                        checks = int(checks_file.read_text()) if checks_file.exists() else 0
                        items = []
                        if os.environ.get('STUB_ACTIVE_JOB') == '1' and live and checks < 2:
                            items.append({{
                                'metadata': {{
                                    'name': 'dind-runner-active',
                                    'labels': {{
                                        'actions.github.com/scale-set-name': 'dind',
                                        'app.kubernetes.io/component': 'runner',
                                    }},
                                }},
                            }})
                        print(json.dumps({{'items': items}}))
                    elif not live:
                        print(json.dumps({{'items': []}}))
                    else:
                        selector = args[args.index('-l') + 1]
                        if selector.startswith('app.kubernetes.io/instance='):
                            items = [{{
                                'metadata': {{'name': 'controller', 'uid': 'controller-uid'}},
                                'status': {{
                                    'phase': 'Running',
                                    'conditions': [{{'type': 'Ready', 'status': 'True'}}],
                                    'containerStatuses': [{{'ready': True, 'restartCount': 0}}],
                                }},
                            }}]
                        else:
                            first_name = (
                                'wrong'
                                if os.environ.get('STUB_WRONG_LISTENER') == '1'
                                else 'dind'
                            )
                            items = [
                                {{
                                    'metadata': {{
                                        'name': 'dind-listener',
                                        'uid': 'dind-listener-uid',
                                        'labels': {{
                                            'actions.github.com/scale-set-name': first_name,
                                        }},
                                    }},
                                    'status': {{
                                        'phase': 'Running',
                                        'conditions': [{{'type': 'Ready', 'status': 'True'}}],
                                        'containerStatuses': [{{'ready': True, 'restartCount': 0}}],
                                    }},
                                }},
                                {{
                                    'metadata': {{
                                        'name': 'linux-listener',
                                        'uid': 'linux-listener-uid',
                                        'labels': {{
                                            'actions.github.com/scale-set-name': 'linux',
                                        }},
                                    }},
                                    'status': {{
                                        'phase': 'Running',
                                        'conditions': [{{'type': 'Ready', 'status': 'True'}}],
                                        'containerStatuses': [{{'ready': True, 'restartCount': 0}}],
                                    }},
                                }},
                            ]
                        print(json.dumps({{'items': items}}))
                else:
                    raise SystemExit(f'unexpected kubectl get target: {{target}}')
            else:
                raise SystemExit(f'unexpected kubectl arguments: {{args}}')
        else:
            raise SystemExit(f'unexpected tool: {{tool}}')
        ''',
    )
    for name in ('aws', 'kubectl', 'terragrunt', 'yq'):
        (bin_dir / name).symlink_to(fake_tool)

    env = os.environ.copy()
    env.update({
        'PATH': f'{bin_dir}:{env["PATH"]}',
        'STUB_CONFIG': str(config),
        'STUB_RUNTIME': str(runtime),
        'ARC_MIGRATION_TIMEOUT_SECONDS': '1',
        'ARC_MIGRATION_DRAIN_TIMEOUT_SECONDS': '1',
        'ARC_MIGRATION_STABILITY_SECONDS': '0',
        'ARC_MIGRATION_QUIESCENCE_SECONDS': '0',
        'ARC_MIGRATION_POLL_SECONDS': '0',
    })
    return tenant_dir, env


def run_script(
    tenant_dir: Path,
    env: dict[str, str],
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [
            'bash', str(SCRIPT),
            '--tf-dir', str(tenant_dir),
            '--from-cluster', 'forge-test-blue',
            '--to-cluster', 'forge-test-green',
            '--expected-account-id', '123456789012',
            '--non-interactive',
        ],
        check=False,
        capture_output=True,
        env=env,
        text=True,
        timeout=10,
    )


def runtime_path(env: dict[str, str], name: str) -> Path:
    return Path(env['STUB_RUNTIME']) / name


def test_normal_migration_reconciles_only_arc(tmp_path: Path) -> None:
    tenant_dir, env = make_fixture(tmp_path)

    result = run_script(tenant_dir, env)

    assert result.returncode == 0, result.stderr
    assert runtime_path(env, 'applies').read_text().splitlines() == [
        'module.arc_runners,forge-test-blue,true',
        'module.arc_runners,forge-test-green,true',
        'module.arc_runners,forge-test-green,false',
    ]
    assert not runtime_path(env, 'live-blue').exists()
    assert runtime_path(env, 'live-green').exists()
    assert 'arc_cluster_name: forge-test-green' in (
        tenant_dir / 'config.yml'
    ).read_text()


def test_success_output_reports_phases_checks_and_wait_numbers(tmp_path: Path) -> None:
    tenant_dir, env = make_fixture(tmp_path)

    result = run_script(tenant_dir, env)

    assert result.returncode == 0, result.stderr
    for level in ('PHASE', 'CHECK', 'WAIT', 'APPLY', 'INFO', 'OK'):
        assert f'[{level}]' in result.stdout
    assert (
        'Timing: operation_timeout=1s drain_timeout=1s '
        'stability_window=0s quiet_window=0s poll_interval=0s.'
    ) in result.stdout
    assert 'Closing scheduling for 2 runner set(s)' in result.stdout
    assert "runner set 'dind' to minRunners=0 and maxRunners=0 (1/2)" in result.stdout
    assert '(timeout 1s)' in result.stdout
    assert 'elapsed 0s' in result.stdout
    phase_index = result.stdout.index('[PHASE]')
    completion_index = result.stdout.index('Migration complete:')
    assert phase_index < completion_index


def test_all_runner_sets_are_patched_before_drain_wait(tmp_path: Path) -> None:
    tenant_dir, env = make_fixture(tmp_path)
    env['STUB_ACTIVE_JOB'] = '1'
    env['STUB_LISTENER_ABSENT_WHILE_ACTIVE'] = '1'
    env['ARC_MIGRATION_DRAIN_TIMEOUT_SECONDS'] = '3'

    result = run_script(tenant_dir, env)

    assert result.returncode == 0, result.stderr
    assert runtime_path(env, 'patched-dind').exists()
    assert runtime_path(env, 'patched-linux').exists()
    assert int(runtime_path(env, 'runner-checks').read_text()) > 1


def test_waits_for_reconciled_zero_capacity_listener(tmp_path: Path) -> None:
    tenant_dir, env = make_fixture(tmp_path)
    env['STUB_LISTENER_DELAY'] = '1'
    env['ARC_MIGRATION_TIMEOUT_SECONDS'] = '3'

    result = run_script(tenant_dir, env)

    assert result.returncode == 0, result.stderr
    assert int(runtime_path(env, 'listener-checks-dind').read_text()) > 1


def test_rerun_accepts_expected_listener_temporarily_absent(tmp_path: Path) -> None:
    tenant_dir, env = make_fixture(tmp_path)
    env['STUB_MISSING_SOURCE_LISTENER'] = '1'
    runtime_path(env, 'patched-dind').touch()

    result = run_script(tenant_dir, env)

    assert result.returncode == 0, result.stderr
    assert runtime_path(env, 'patched-linux').exists()


def test_unexpected_source_runner_set_stops_before_changes(tmp_path: Path) -> None:
    tenant_dir, env = make_fixture(tmp_path)
    env['STUB_EXTRA_SOURCE_RUNNER'] = '1'

    result = run_script(tenant_dir, env)

    assert result.returncode != 0
    assert 'source ARC inventory differs' in result.stderr
    assert not runtime_path(env, 'applies').exists()
    assert not runtime_path(env, 'patched-dind').exists()


def test_source_residue_without_namespace_skips_runner_drain(tmp_path: Path) -> None:
    tenant_dir, env = make_fixture(tmp_path)
    env['STUB_SOURCE_NAMESPACE_ABSENT'] = '1'

    result = run_script(tenant_dir, env)

    assert result.returncode == 0, result.stderr
    assert not runtime_path(env, 'patched-dind').exists()
    assert not runtime_path(env, 'live-blue').exists()


def test_orphaned_source_stops_before_destination_applies(tmp_path: Path) -> None:
    tenant_dir, env = make_fixture(tmp_path)
    env['STUB_ORPHAN_SOURCE'] = '1'

    result = run_script(tenant_dir, env)

    assert result.returncode != 0
    assert 'source cluster' in result.stderr
    assert runtime_path(env, 'applies').read_text().splitlines() == [
        'module.arc_runners,forge-test-blue,true',
    ]
    assert not runtime_path(env, 'live-green').exists()


def test_both_clusters_live_stops_before_drain_or_apply(tmp_path: Path) -> None:
    tenant_dir, env = make_fixture(tmp_path)
    runtime_path(env, 'live-green').touch()

    result = run_script(tenant_dir, env)

    assert result.returncode != 0
    assert 'live footprint on both' in result.stderr
    assert not runtime_path(env, 'applies').exists()
    assert not runtime_path(env, 'patched-dind').exists()


def test_destination_session_conflict_fails_health_check(tmp_path: Path) -> None:
    tenant_dir, env = make_fixture(tmp_path)
    env['STUB_CONFLICT'] = '1'

    result = run_script(tenant_dir, env)

    assert result.returncode != 0
    assert 'did not remain healthy and conflict-free' in result.stderr
    assert 'Migration complete' not in result.stdout


def test_checked_out_destination_config_is_normalized(tmp_path: Path) -> None:
    tenant_dir, env = make_fixture(tmp_path)
    (tenant_dir / 'config.yml').write_text(
        'arc_cluster_name: forge-test-green\nmigrate_arc_cluster: false\n',
        encoding='utf-8',
    )

    result = run_script(tenant_dir, env)

    assert result.returncode == 0, result.stderr
    assert runtime_path(env, 'applies').read_text().splitlines()[0] == (
        'module.arc_runners,forge-test-blue,true'
    )


def test_clean_source_and_live_destination_reconciles_arc(
    tmp_path: Path,
) -> None:
    tenant_dir, env = make_fixture(tmp_path)
    runtime_path(env, 'live-blue').unlink()
    runtime_path(env, 'live-green').touch()

    result = run_script(tenant_dir, env)

    assert result.returncode == 0, result.stderr
    assert runtime_path(env, 'applies').read_text().splitlines() == [
        'module.arc_runners,forge-test-green,false',
    ]


def test_wrong_account_stops_before_cluster_changes(tmp_path: Path) -> None:
    tenant_dir, env = make_fixture(tmp_path)
    env['STUB_ACCOUNT'] = '999999999999'

    result = run_script(tenant_dir, env)

    assert result.returncode != 0
    assert 'AWS account mismatch' in result.stderr
    assert not runtime_path(env, 'applies').exists()


def test_listener_names_must_match_configuration(tmp_path: Path) -> None:
    tenant_dir, env = make_fixture(tmp_path)
    env['STUB_WRONG_LISTENER'] = '1'

    result = run_script(tenant_dir, env)

    assert result.returncode != 0
    assert 'did not remain healthy and conflict-free' in result.stderr


def test_no_state_or_plan_commands_are_used() -> None:
    source = SCRIPT.read_text(encoding='utf-8')

    assert 'terragrunt output' not in source
    assert 'terragrunt state' not in source
    assert 'terragrunt plan' not in source
    assert 'tofu ' not in source


def test_blue_green_pair_is_required(tmp_path: Path) -> None:
    tenant_dir, env = make_fixture(tmp_path)

    result = subprocess.run(
        [
            'bash', str(SCRIPT),
            '--tf-dir', str(tenant_dir),
            '--from-cluster', 'forge-one-blue',
            '--to-cluster', 'forge-two-green',
            '--expected-account-id', '123456789012',
            '--non-interactive',
        ],
        check=False,
        capture_output=True,
        env=env,
        text=True,
    )

    assert result.returncode != 0
    assert 'not a blue/green pair' in result.stderr
