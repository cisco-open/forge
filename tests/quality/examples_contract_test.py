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
