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
