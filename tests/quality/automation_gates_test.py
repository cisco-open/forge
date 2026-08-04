import ast
import json
import re
import tomllib
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    return (REPO_ROOT / path).read_text(encoding='utf-8')


def is_terraform_module(path: Path) -> bool:
    if not path.is_dir():
        return False
    if '.terraform' in path.parts:
        return False
    return any(path.glob('*.tf'))


def contains_module_interface_contract(path: Path) -> bool:
    source = path.read_text(encoding='utf-8')
    return path.name.endswith('.tftest.hcl') and 'tests/tofu/module_interface_contract' in source


def is_module_interface_contract(path: Path) -> bool:
    has_interface_suffix = path.name.endswith(
        '_interface_contract.tftest.hcl',
    )
    return has_interface_suffix and contains_module_interface_contract(path)


def contains_source_inventory_contract(path: Path) -> bool:
    source = path.read_text(encoding='utf-8')
    return path.name.endswith('.tftest.hcl') and 'tests/tofu/module_contract' in source


def is_source_inventory_contract(path: Path) -> bool:
    has_source_inventory_suffix = path.name.endswith(
        '_source_inventory.tftest.hcl',
    )
    return has_source_inventory_suffix and contains_source_inventory_contract(path)


def is_behavior_contract(path: Path) -> bool:
    source = path.read_text(encoding='utf-8')
    if 'tests/tofu/module_contract' in source:
        return False
    if 'tests/tofu/module_interface_contract' in source:
        return False
    if path.name.endswith('_validation_contract.tftest.hcl'):
        return False
    return any(
        marker in source
        for marker in ('mock_provider', 'assert {', 'expect_failures')
    )


def dependency_group_names(group_name: str) -> set[str]:
    data = tomllib.loads(read('pyproject.toml'))
    dependencies = data['dependency-groups'][group_name]
    return {
        re.split(
            r'\s*(?:\[|==|~=|!=|<=|>=|<|>|;)',
            dependency,
            maxsplit=1,
        )[0].lower()
        for dependency in dependencies
    }


def test_renovate_groups_runner_updates_by_semver_level() -> None:
    config = json.loads(read('renovate.json'))
    runner_rule = next(
        rule
        for rule in config['packageRules']
        if rule.get('groupSlug') == 'terraform-aws-github-runner'
    )

    assert config['separateMajorMinor'] is True
    assert config['separateMinorPatch'] is True
    assert runner_rule['separateMajorMinor'] is True
    assert runner_rule['separateMinorPatch'] is True


def test_renovate_merges_config_from_selected_base_branch() -> None:
    config = json.loads(read('renovate.json'))

    assert config['useBaseBranchConfig'] == 'merge'


def test_renovate_pre_commit_hooks_have_single_update_owner() -> None:
    config = json.loads(read('renovate.json'))
    pre_commit_path = '.pre-commit-config.yaml'

    assert config['pre-commit']['enabled'] is True

    overlapping_custom_managers = [
        manager.get('description', '<unnamed>')
        for manager in config['customManagers']
        if any(
            re.search(file_pattern, pre_commit_path)
            for file_pattern in manager.get('fileMatch', [])
        )
    ]
    assert overlapping_custom_managers == []

    group_rules = [
        rule
        for rule in config['packageRules']
        if rule.get('groupSlug') == 'pre-commit-dependencies'
    ]
    assert len(group_rules) == 1
    assert group_rules[0]['matchManagers'] == ['pre-commit']
    assert 'pinDigests' not in group_rules[0]

    digest_rule = next(
        rule
        for rule in config['packageRules']
        if rule.get('description') == (
            'Ignore digest-only refreshes for frozen pre-commit hooks'
        )
    )
    assert digest_rule['matchManagers'] == ['pre-commit']
    assert digest_rule['matchUpdateTypes'] == ['digest']
    assert digest_rule['enabled'] is False

    frozen_revision = re.compile(
        r'^\s*rev: [a-f0-9]{40}\s+# frozen: \S+$',
    )
    revision_lines = [
        line
        for line in read(pre_commit_path).splitlines()
        if line.lstrip().startswith('rev:')
    ]
    assert revision_lines
    assert all(frozen_revision.match(line) for line in revision_lines)


def test_renovate_groups_and_pins_executable_github_action_dependencies() -> None:
    config = json.loads(read('renovate.json'))
    executable_dep_types = {
        'action',
        'container',
        'docker',
        'service',
    }
    github_actions_rules = [
        rule
        for rule in config['packageRules']
        if rule.get('matchManagers') == ['github-actions']
    ]
    executable_group_rules = [
        rule
        for rule in github_actions_rules
        if rule.get('matchDepTypes')
    ]
    assert len(executable_group_rules) == 1
    assert github_actions_rules == executable_group_rules
    group_rule = executable_group_rules[0]

    assert set(group_rule['matchDepTypes']) == executable_dep_types
    assert group_rule['pinDigests'] is True
    assert group_rule['groupName'] == (
        'GitHub Actions {{{updateType}}} dependencies'
    )
    assert group_rule['groupSlug'] == (
        'github-actions-{{{updateType}}}-dependencies'
    )
    assert group_rule['separateMajorMinor'] is False
    assert group_rule['separateMinorPatch'] is False
    assert 'uses-with' not in group_rule['matchDepTypes']


def test_renovate_manages_supported_lambda_layer_arns() -> None:
    config = json.loads(read('renovate.json'))
    managers = {
        manager.get('datasourceTemplate'): manager
        for manager in config['customManagers']
        if manager.get('datasourceTemplate') in {
            'custom.klayers',
            'custom.aws-sdk-pandas-layers',
        }
    }

    assert set(managers) == {
        'custom.klayers',
        'custom.aws-sdk-pandas-layers',
    }
    assert all(
        manager['fileMatch'] == [r'^.*\.tf$']
        for manager in managers.values()
    )

    compiled_patterns = {
        datasource: [
            re.compile(
                re.sub(
                    r'\(\?<([A-Za-z][A-Za-z0-9_]*)>',
                    r'(?P<\1>',
                    pattern,
                ),
            )
            for pattern in manager['matchStrings']
        ]
        for datasource, manager in managers.items()
    }

    supported_arn_pattern = re.compile(
        r'arn:aws(?:-[a-z]+)*:lambda:'
        r'(?:\$\{[^}]+\}|[a-z0-9-]+):'
        r'(?:'
        r'770693421928:layer:Klayers-[A-Za-z0-9._-]+'
        r'|\d{12}:layer:AWSSDKPandas-[A-Za-z0-9._-]+'
        r'):\d+',
    )
    source_arns = []
    source_texts = {}
    for path in sorted((REPO_ROOT / 'modules').rglob('*.tf')):
        if '.terraform' in path.parts:
            continue
        source_texts[path] = path.read_text(encoding='utf-8')
        source_arns.extend(
            (path, match)
            for match in supported_arn_pattern.finditer(source_texts[path])
        )

    matched_datasources = []
    matched_packages = []
    manager_match_count = sum(
        len(list(pattern.finditer(source_text)))
        for source_text in source_texts.values()
        for patterns in compiled_patterns.values()
        for pattern in patterns
    )
    for path, arn_match in source_arns:
        matches = [
            (datasource, match)
            for datasource, patterns in compiled_patterns.items()
            for pattern in patterns
            for match in pattern.finditer(source_texts[path])
            if match.start() <= arn_match.start() <= arn_match.end()
            if arn_match.end() <= match.end()
        ]
        assert len(matches) == 1, arn_match.group()
        datasource, match = matches[0]
        matched_datasources.append(datasource)
        groups = match.groupdict()
        package = groups.get('layerPackage') or groups.get('layerName')
        matched_packages.append(package)

    assert len(source_arns) == 21
    assert manager_match_count == len(source_arns)
    assert matched_datasources.count('custom.klayers') == 18
    assert matched_datasources.count('custom.aws-sdk-pandas-layers') == 3
    assert set(matched_packages) == {
        'AWSSDKPandas-Python312',
        'PyJWT',
        'cryptography',
        'requests',
    }

    klayers_literal = (
        'arn:aws:lambda:eu-west-1:770693421928:'
        'layer:Klayers-p312-arm64-requests:4'
    )
    klayers_match = compiled_patterns['custom.klayers'][0].fullmatch(
        klayers_literal,
    )
    assert klayers_match is not None
    assert klayers_match.groupdict() == {
        'lookupRegion': 'eu-west-1',
        'pythonMajor': '3',
        'pythonMinor': '12',
        'architecture': '-arm64',
        'layerPackage': 'requests',
        'currentValue': '4',
    }

    klayers_dynamic = (
        '"arn:aws:lambda:${var.aws_region}:770693421928:'
        'layer:Klayers-p312-requests:4"'
    )
    klayers_dynamic_match = compiled_patterns[
        'custom.klayers'
    ][1].search(klayers_dynamic)
    assert klayers_dynamic_match is not None
    assert klayers_dynamic_match.group('layerPackage') == 'requests'
    assert 'lookupRegion' not in klayers_dynamic_match.groupdict()

    assert all(
        'lambdaLayerRegion' not in pattern
        for manager in managers.values()
        for pattern in manager['matchStrings']
    )
    assert all(
        '{{else}}us-east-1{{/if}}' in manager['packageNameTemplate']
        for manager in managers.values()
    )
    assert all(
        'lambdaLayerRegion' not in source_text
        for source_text in source_texts.values()
    )

    pandas_literal = (
        'arn:aws-cn:lambda:cn-north-1:123456789012:'
        'layer:AWSSDKPandas-Python312-Arm64:8'
    )
    pandas_match = compiled_patterns[
        'custom.aws-sdk-pandas-layers'
    ][0].fullmatch(pandas_literal)
    assert pandas_match is not None
    assert pandas_match.groupdict() == {
        'partition': 'aws-cn',
        'lookupRegion': 'cn-north-1',
        'publisherAccount': '123456789012',
        'layerName': 'AWSSDKPandas-Python312-Arm64',
        'currentValue': '8',
    }

    unsupported_arn = (
        'arn:aws:lambda:eu-west-1:123456789012:'
        'layer:private-application-layer:7'
    )
    assert not any(
        pattern.fullmatch(unsupported_arn)
        for patterns in compiled_patterns.values()
        for pattern in patterns
    )

    assert all(
        manager['versioningTemplate'] == r'regex:^(?<patch>\d+)$'
        for manager in managers.values()
    )
    pandas_datasource = config['customDatasources']['aws-sdk-pandas-layers']
    assert pandas_datasource['format'] == 'plain'
    assert '/stable/_sources/layers.rst.txt' in (
        pandas_datasource['defaultRegistryUrlTemplate']
    )

    layer_rule = next(
        rule
        for rule in config['packageRules']
        if rule.get('groupSlug') == 'aws-lambda-layers'
    )
    assert set(layer_rule['matchDatasources']) == set(managers)
    assert layer_rule['automerge'] is False
    assert layer_rule['minimumReleaseAge'] is None

    inherited_patch_policy = {
        'security',
        'critical',
        'simple-review',
        'auto-merge',
    }
    for rule in config['packageRules']:
        if 'patch' not in rule.get('matchUpdateTypes', []):
            continue
        if rule.get('matchDepTypes'):
            continue
        changes_layer_policy = any(
            (
                rule.get('automerge') is True,
                bool(
                    inherited_patch_policy.intersection(
                        rule.get('addLabels', []),
                    ),
                ),
                'prPriority' in rule,
                'prCreation' in rule,
            ),
        )
        if not changes_layer_policy:
            continue
        assert {
            f'!{datasource}' for datasource in managers
        }.issubset(rule.get('matchDatasources', []))


def test_python_ssm_clients_use_explicit_retry_config() -> None:
    missing_config = []

    for path in sorted((REPO_ROOT / 'modules').rglob('*.py')):
        tree = ast.parse(path.read_text(encoding='utf-8'))
        for node in ast.walk(tree):
            if not isinstance(node, ast.Call):
                continue
            if not isinstance(node.func, ast.Attribute):
                continue
            is_boto3_client = all((
                isinstance(node.func.value, ast.Name),
                getattr(node.func.value, 'id', None) == 'boto3',
                node.func.attr == 'client',
            ))
            if not is_boto3_client:
                continue
            first_arg = node.args[0] if node.args else None
            if not isinstance(first_arg, ast.Constant):
                continue
            if first_arg.value != 'ssm':
                continue
            if not any(keyword.arg == 'config' for keyword in node.keywords):
                relative_path = path.relative_to(REPO_ROOT).as_posix()
                missing_config.append(f'{relative_path}:{node.lineno}')

    assert missing_config == []


def test_each_module_has_specific_native_test_file() -> None:
    modules = sorted(
        path
        for path in (REPO_ROOT / 'modules').rglob('*')
        if is_terraform_module(path)
    )

    missing_tests = []
    generic_tests = []
    for module in modules:
        tests_dir = module / 'tests'
        if tests_dir.exists():
            tests = sorted(tests_dir.glob('*.tftest.hcl'))
        else:
            tests = []
        if not tests:
            missing_tests.append(module.relative_to(REPO_ROOT).as_posix())
        for test_file in tests:
            if test_file.name in {
                'module_contract.tftest.hcl',
                'module_static_contract.tftest.hcl',
            }:
                generic_tests.append(
                    test_file.relative_to(REPO_ROOT).as_posix())

    assert missing_tests == []
    assert generic_tests == []


def test_each_module_has_one_interface_contract() -> None:
    modules = sorted(
        path
        for path in (REPO_ROOT / 'modules').rglob('*')
        if is_terraform_module(path)
    )

    missing_interface_tests = []
    misnamed_interface_tests = []
    duplicate_interface_tests = []
    for module in modules:
        tests_dir = module / 'tests'
        tests = sorted(tests_dir.glob('*.tftest.hcl')
                       ) if tests_dir.exists() else []
        misnamed_interface_tests.extend(
            test_file.relative_to(REPO_ROOT).as_posix()
            for test_file in tests
            if contains_module_interface_contract(test_file)
            if not test_file.name.endswith('_interface_contract.tftest.hcl')
        )
        interface_tests = (
            sorted(
                test_file
                for test_file in tests
                if is_module_interface_contract(test_file)
            )
        )
        if not interface_tests:
            missing_interface_tests.append(
                module.relative_to(REPO_ROOT).as_posix(),
            )
        elif len(interface_tests) > 1:
            module_path = module.relative_to(REPO_ROOT).as_posix()
            test_paths = ', '.join(
                test_file.relative_to(REPO_ROOT).as_posix()
                for test_file in interface_tests
            )
            duplicate_interface_tests.append(f'{module_path}: {test_paths}')

    assert missing_interface_tests == []
    assert misnamed_interface_tests == []
    assert duplicate_interface_tests == []


def test_each_module_has_one_source_inventory_contract() -> None:
    modules = sorted(
        path
        for path in (REPO_ROOT / 'modules').rglob('*')
        if is_terraform_module(path)
    )

    missing_inventory_tests = []
    misnamed_inventory_tests = []
    duplicate_inventory_tests = []
    for module in modules:
        tests_dir = module / 'tests'
        tests = sorted(tests_dir.glob('*.tftest.hcl')
                       ) if tests_dir.exists() else []
        misnamed_inventory_tests.extend(
            test_file.relative_to(REPO_ROOT).as_posix()
            for test_file in tests
            if contains_source_inventory_contract(test_file)
            if not test_file.name.endswith('_source_inventory.tftest.hcl')
        )
        inventory_tests = (
            sorted(
                test_file
                for test_file in tests
                if is_source_inventory_contract(test_file)
            )
        )
        if not inventory_tests:
            missing_inventory_tests.append(
                module.relative_to(REPO_ROOT).as_posix(),
            )
        elif len(inventory_tests) > 1:
            module_path = module.relative_to(REPO_ROOT).as_posix()
            test_paths = ', '.join(
                test_file.relative_to(REPO_ROOT).as_posix()
                for test_file in inventory_tests
            )
            duplicate_inventory_tests.append(f'{module_path}: {test_paths}')

    assert missing_inventory_tests == []
    assert misnamed_inventory_tests == []
    assert duplicate_inventory_tests == []


def test_behavior_contracts_use_behavior_suffix() -> None:
    misnamed_behavior_tests = [
        test_file.relative_to(REPO_ROOT).as_posix()
        for test_file in sorted(
            (REPO_ROOT / 'modules').glob('**/tests/*.tftest.hcl'),
        )
        if is_behavior_contract(test_file)
        if not test_file.name.endswith('_behavior.tftest.hcl')
    ]

    assert misnamed_behavior_tests == []


def test_pre_commit_covers_security_sca_and_secrets() -> None:
    pre_commit = read('.pre-commit-config.yaml')
    pyproject = read('pyproject.toml')
    dockerfile = read('.docker/pre-commit/Dockerfile')
    workflow = read('.github/workflows/quality-gates.yml')
    pre_commit_workflow = read('.github/workflows/pre-commit.yml')
    pre_commit_deps = dependency_group_names('pre-commit-image')

    for required in [
        'repo: https://github.com/gitleaks/gitleaks',
        'id: gitleaks',
        'gitleaks detect --source . --config .gitleaks.toml',
        'repo: https://github.com/PyCQA/bandit',
        'id: bandit',
        '- modules',
        '- tests',
        '*/.terraform/*',
        'repo: https://github.com/pypa/pip-audit',
        'id: pip-audit',
        'uv export --project . --locked --only-group lambda-tests',
        'pip-audit -r "$req" --strict --no-deps --disable-pip',
    ]:
        assert required in pre_commit

    pip_audit_block = pre_commit.split(
        'repo: https://github.com/pypa/pip-audit',
        1,
    )[1].split('  # ---------------------', 1)[0]
    assert 'additional_dependencies:' not in pip_audit_block
    assert 'uv==' not in pip_audit_block

    assert 'pre-commit-image = [' in pyproject
    assert {'pre-commit', 'bandit', 'pip-audit', 'uv'} <= pre_commit_deps

    for required in [
        'COPY pyproject.toml uv.lock ./',
        'python3.12-venv',
        'data["dependency-groups"]["pre-commit-image"]',
        'uv export --locked --only-group pre-commit-image',
        'pip install --no-cache-dir --break-system-packages --ignore-installed -r /tmp/pre-commit-image-requirements.txt',
    ]:
        assert required in dockerfile

    for required in [
        'working-directory: tests',
        'pytest -q quality',
        'pytest -q mutation',
    ]:
        assert required in workflow

    for removed in [
        'name: Ensure pre-commit system tools',
        'command -v bandit',
        'command -v pip-audit',
        'apt-get install -y --no-install-recommends python3.12-venv',
        'uv export --locked --only-group pre-commit-image',
        '/tmp/pre-commit-image-requirements.txt',
    ]:
        assert removed not in pre_commit_workflow


def test_github_app_register_image_uses_root_locked_dependencies() -> None:
    requirements_path = (
        REPO_ROOT / '.docker/forge-github-app-register/requirements.txt'
    )
    assert not requirements_path.exists()

    pyproject = read('pyproject.toml')
    dockerfile = read('.docker/forge-github-app-register/Dockerfile')
    workflow = read('.github/workflows/build-forge-github-app-register.yml')
    dependabot = read('.github/dependabot.yml')
    renovate = read('renovate.json')
    register_deps = dependency_group_names('forge-github-app-register')

    assert 'forge-github-app-register = [' in pyproject
    assert {'flask', 'requests', 'uv'} <= register_deps

    for required in [
        'COPY pyproject.toml uv.lock ./',
        'data["dependency-groups"]["forge-github-app-register"]',
        'uv export --locked --only-group forge-github-app-register',
        'COPY --chown=appuser:appuser .docker/forge-github-app-register/app.py .',
    ]:
        assert required in dockerfile

    assert 'context: .' in workflow
    assert 'pyproject.toml' in workflow
    assert 'uv.lock' in workflow
    uv_dependabot_block = dependabot.split(
        '  - package-ecosystem: uv',
        1,
    )[1].split('  - package-ecosystem: pre-commit', 1)[0]
    assert '  - package-ecosystem: pip' not in dependabot
    assert '- /.docker/forge-github-app-register' not in uv_dependabot_block
    assert '.docker/forge-github-app-register/requirements.txt' not in renovate
    assert 'requirements*.txt' not in renovate
    assert 'uv.lock' in renovate
    assert 'lockFileMaintenance' in renovate


def test_test_suites_have_named_ci_jobs() -> None:
    lambda_workflow = read('.github/workflows/lambda-tests.yml')
    iac_workflow = read('.github/workflows/iac-policy.yml')
    quality_workflow = read('.github/workflows/quality-gates.yml')
    smoke_workflow = read('.github/workflows/ministack-smoke.yml')
    fuzz_workflow = read('.github/workflows/cflite_pr.yml')

    for required in [
        'name: Lambda unit tests',
        'pytest -q lambdas',
    ]:
        assert required in lambda_workflow

    for required in [
        'name: Offline IaC contract tests',
        'pytest -q iac',
        'tofu -chdir="${module}" test -no-color',
        'conftest verify --policy policy/opa',
        'modules/**/*.sh',
        'tests/iac/**',
        'tests/tofu/**',
    ]:
        assert required in iac_workflow

    for required in [
        'name: Automation gate tests',
        'pytest -q quality',
        'scripts/ci_summary.py',
        'scripts/terragrunt-deps.py',
        'name: Mutation test critical Lambda boundaries',
        'pytest -q mutation',
    ]:
        assert required in quality_workflow

    for required in [
        'name: MiniStack smoke + real-handler exec',
        'docker compose up --wait',
        'pytest -m smoke -q',
        'pytest -m lambda_exec -q',
    ]:
        assert required in smoke_workflow
    assert 'Wait for readiness' not in smoke_workflow

    for required in [
        'name: Python fuzzers (${{ matrix.sanitizer }})',
        'fuzz/**',
        'build_fuzzers',
        'run_fuzzers',
    ]:
        assert required in fuzz_workflow


def test_mutation_config_targets_trusted_input_boundaries() -> None:
    required_targets = {
        'tests/mutation/webhook_signature_mutation_test.py': [
            'github_webhook_relay/source/lambda/',
            'validate_signature.py',
            'accepts_missing_or_wrong_signature',
            'uses_legacy_sha1_digest',
        ],
        'tests/mutation/redrive_deadletter_mutation_test.py': [
            'redrive_deadletter.py',
            'uses_main_queue_as_redrive_source',
            'reports_client_error_as_started',
        ],
        'tests/mutation/trust_boundary_mutation_test.py': [
            'trust_common.py',
            'allows_delay_outside_bounds',
            'allows_session_policy_for_all_resources',
        ],
        'tests/mutation/job_log_archiver_mutation_test.py': [
            'job_log_archiver.py',
            'swallows_archiver_exceptions',
            'ignores_metadata_field_limit',
        ],
        'tests/mutation/splunk_stuck_dispatcher_mutation_test.py': [
            'splunk_stuck_workflow_job_dispatcher/lambda/',
            'accepts_wrong_webhook_token',
            'omits_tenant_region_from_dedupe_key',
        ],
        'tests/mutation/github_app_runner_group_mutation_test.py': [
            'github_app_runner_group.py',
            'reads_ssm_without_decryption',
            'skips_selected_repository_listing',
        ],
    }

    for test_path, required_strings in required_targets.items():
        mutation_test = read(test_path)
        for required in required_strings:
            assert required in mutation_test
