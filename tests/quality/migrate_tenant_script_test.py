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
                with (runtime / 'applies').open('a', encoding='utf-8') as log:
                    log.write(f'{{cluster}},{{migrate}}\\n')
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
                    print('namespace/tenant-a' if live else '')
                elif target.startswith('nodepool') or target.startswith('ec2nodeclass'):
                    print('')
                elif target.startswith('autoscalingrunnerset'):
                    runner = args[args.index('get') + 2]
                    if not live:
                        raise SystemExit(1)
                    if '-o' not in args:
                        print(f'autoscalingrunnerset.actions.github.com/{{runner}}')
                    else:
                        if os.environ.get('STUB_ACTIVE_JOB') == '1':
                            if not all(
                                (runtime / f'patched-{{name}}').exists()
                                for name in ('dind', 'linux')
                            ):
                                raise SystemExit('all scale sets must be patched first')
                            checks_file = runtime / 'runner-checks'
                            checks = int(checks_file.read_text()) + 1 if checks_file.exists() else 1
                            checks_file.write_text(str(checks), encoding='utf-8')
                        else:
                            checks = 2
                        print(json.dumps({{
                            'status': {{
                                'currentRunners': 0,
                                'pendingEphemeralRunners': 0,
                                'runningEphemeralRunners': int(
                                    os.environ.get('STUB_ACTIVE_JOB') == '1'
                                    and runner == 'dind'
                                    and checks == 1
                                ),
                            }},
                        }}))
                elif target == 'pods':
                    if '-l' not in args:
                        print(json.dumps({{'items': []}}))
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
        'ARC_MIGRATION_STABILITY_SECONDS': '0',
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


def test_normal_migration_uses_three_arc_applies(tmp_path: Path) -> None:
    tenant_dir, env = make_fixture(tmp_path)

    result = run_script(tenant_dir, env)

    assert result.returncode == 0, result.stderr
    assert runtime_path(env, 'applies').read_text().splitlines() == [
        'forge-test-blue,true',
        'forge-test-green,true',
        'forge-test-green,false',
    ]
    assert not runtime_path(env, 'live-blue').exists()
    assert runtime_path(env, 'live-green').exists()
    assert 'arc_cluster_name: forge-test-green' in (
        tenant_dir / 'config.yml'
    ).read_text()


def test_all_runner_sets_are_patched_before_drain_wait(tmp_path: Path) -> None:
    tenant_dir, env = make_fixture(tmp_path)
    env['STUB_ACTIVE_JOB'] = '1'

    result = run_script(tenant_dir, env)

    assert result.returncode == 0, result.stderr
    assert runtime_path(env, 'patched-dind').exists()
    assert runtime_path(env, 'patched-linux').exists()
    assert int(runtime_path(env, 'runner-checks').read_text()) > 1


def test_orphaned_source_stops_before_destination_applies(tmp_path: Path) -> None:
    tenant_dir, env = make_fixture(tmp_path)
    env['STUB_ORPHAN_SOURCE'] = '1'

    result = run_script(tenant_dir, env)

    assert result.returncode != 0
    assert 'source cluster' in result.stderr
    assert runtime_path(env, 'applies').read_text().splitlines() == [
        'forge-test-blue,true',
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
        'forge-test-blue,true'
    )


def test_clean_source_and_live_destination_resume_with_one_apply(
    tmp_path: Path,
) -> None:
    tenant_dir, env = make_fixture(tmp_path)
    runtime_path(env, 'live-blue').unlink()
    runtime_path(env, 'live-green').touch()

    result = run_script(tenant_dir, env)

    assert result.returncode == 0, result.stderr
    assert runtime_path(env, 'applies').read_text().splitlines() == [
        'forge-test-green,false',
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
