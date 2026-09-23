from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
EXAMPLES = REPO_ROOT / 'examples'


def release_module_blocks() -> dict[str, dict[str, str]]:
    blocks: dict[str, dict[str, str]] = {}
    for release_file in sorted(
        (EXAMPLES / 'deployments').glob('*/release_versions.yml')
    ):
        current_key = ''
        current_values: dict[str, str] = {}
        for raw_line in release_file.read_text(encoding='utf-8').splitlines():
            if raw_line.startswith('      ') and raw_line.endswith(':'):
                if current_key:
                    blocks[current_key] = current_values
                current_key = raw_line.strip().removesuffix(':')
                current_values = {'release_file': str(release_file)}
                continue
            if current_key and raw_line.startswith('        '):
                key, sep, value = raw_line.strip().partition(':')
                if sep:
                    current_values[key] = value.strip()

        if current_key:
            blocks[current_key] = current_values

    return blocks


def template_module_key(template: Path) -> str:
    family = template.relative_to(EXAMPLES / 'templates').parts[0]
    name = template.parent.name
    if family == 'platform' and name == 'tenant':
        return 'forge_runners'
    return name


def test_release_versions_reference_existing_local_modules() -> None:
    blocks = release_module_blocks()
    assert blocks

    for module_key, values in blocks.items():
        module_path = values.get('module_path', '')
        module_dir = REPO_ROOT / module_path
        assert values.get('local_path') == '../forge', module_key
        assert values.get('repo') == 'git@github.com:cisco-open/forge.git', (
            module_key
        )
        assert values.get('ref') == 'main', module_key
        assert module_path.startswith('modules/'), module_key
        assert module_dir.is_dir(), module_key
        assert any(module_dir.glob('*.tf')), module_key


def test_config_templates_have_matching_release_version_entries() -> None:
    blocks = release_module_blocks()
    templates = sorted((EXAMPLES / 'templates').glob('*/*/config.yml'))
    assert templates

    missing = []
    wrong_paths = []
    for template in templates:
        family = template.relative_to(EXAMPLES / 'templates').parts[0]
        module_key = template_module_key(template)
        block = blocks.get(module_key)
        if block is None:
            missing.append(str(template.relative_to(REPO_ROOT)))
            continue

        expected_path = (
            'modules/platform/forge_runners'
            if module_key == 'forge_runners'
            else f'modules/{family}/{module_key}'
        )
        if block.get('module_path') != expected_path:
            wrong_paths.append(
                f'{module_key}: {block.get("module_path")} != {expected_path}'
            )

    assert missing == []
    assert wrong_paths == []


def test_platform_tenant_template_keeps_ec2_and_arc_runner_inputs() -> None:
    template = (
        EXAMPLES / 'templates' / 'platform' / 'tenant' / 'config.yml'
    ).read_text(encoding='utf-8')
    release = (
        EXAMPLES / 'deployments' / 'platform' / 'release_versions.yml'
    ).read_text(
        encoding='utf-8'
    )

    for required in [
        'ec2_runner_specs:',
        'arc_runner_specs:',
        'github_webhook_relay:',
        'github_app:',
        'module_path: modules/platform/forge_runners',
    ]:
        assert required in f'{template}\n{release}'


def test_dependency_monitor_example_is_regional_and_ordered() -> None:
    integration_root = (
        EXAMPLES / 'deployments' / 'integrations' / 'terragrunt'
    )
    global_config = integration_root.joinpath(
        '_global_settings',
        'splunk_dependency_monitor.hcl',
    ).read_text(encoding='utf-8')
    regional_config = integration_root.joinpath(
        'environments',
        'prod',
        'regions',
        'eu-west-1',
        'splunk_dependency_monitor',
        'config.yml',
    ).read_text(encoding='utf-8')

    for required in [
        'find_in_parent_folders("splunk_o11y_conf_shared")',
        'find_in_parent_folders("splunk_secrets")',
        'aws_region   = local.region',
    ]:
        assert required in global_config

    assert "github_api_version: '2022-11-28'" in regional_config
    assert 'name_prefix:' not in regional_config
    assert 'tenant_configs:' not in regional_config


def test_splunk_data_manager_example_documents_aws_config_handoff() -> None:
    integration_root = (
        EXAMPLES / 'deployments' / 'integrations' / 'terragrunt'
    )
    global_config = integration_root.joinpath(
        '_global_settings',
        'splunk_cloud_data_manager.hcl',
    ).read_text(encoding='utf-8')
    deployment_config = integration_root.joinpath(
        'environments',
        'prod',
        'splunk_cloud_data_manager',
        'config.yml',
    ).read_text(encoding='utf-8')
    template_config = EXAMPLES.joinpath(
        'templates',
        'integrations',
        'splunk_cloud_data_manager',
        'config.yml',
    ).read_text(encoding='utf-8')
    producer_outputs = REPO_ROOT.joinpath(
        'modules',
        'helpers',
        'aws_config_recording',
        'outputs.tf',
    ).read_text(encoding='utf-8')

    assert 'dependency "aws_config_recording"' not in global_config
    assert (
        's3_logs_config               = '
        'local.splunk_cloud.locals.s3_logs_config'
    ) in global_config

    assert deployment_config.count('name: forge-aws-config-prod') == 1
    assert (
        '    - enabled: false\n      name: forge-aws-config-prod'
        in deployment_config
    )
    deployment_aws_config = deployment_config.split(
        '      name: forge-aws-config-prod', 1
    )[1].split('\n  ct-logs:', 1)[0]

    for required in [
        'name: forge-s3-logs-prod',
        'source_type: forgecicd:runner-logs:s3',
    ]:
        assert required in deployment_config

    for required in [
        'iam_region: eu-west-1',
        'index: forge-prod-index',
        'source_type: forgecicd:aws:config:s3',
        'splunk_s3_logs.sqs.url',
        'splunk_s3_logs.bucket_arn',
        'splunk_s3_logs.bucket_kms_key_arn',
        'sqs_urls: []',
        's3_bucket_patterns: []',
        'kms_key_arns: []',
    ]:
        assert required in deployment_aws_config

    assert template_config.count('name: forge-aws-config-prod') == 1
    assert (
        '    - enabled: false                        # enable only after '
        'the producer output and Splunk parser are validated\n'
        '      name: forge-aws-config-prod'
    ) in template_config
    template_aws_config = template_config.split(
        '      name: forge-aws-config-prod', 1
    )[1].split('\n  ct-logs:', 1)[0]

    for required in [
        'source_type: forgecicd:aws:config:s3',
        'splunk_s3_logs.sqs.url',
        'splunk_s3_logs.bucket_arn',
        'splunk_s3_logs.bucket_kms_key_arn',
        'sqs_urls: []',
        's3_bucket_patterns: []',
        'kms_key_arns: []',
    ]:
        assert required in template_aws_config

    for required in [
        'output "splunk_s3_logs"',
        'bucket_arn',
        'bucket_kms_key_arn',
        'sqs = {',
        'url',
    ]:
        assert required in producer_outputs
