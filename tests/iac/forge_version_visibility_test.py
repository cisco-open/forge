from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
MODULE = REPO_ROOT / 'modules/platform/forge_runners'
TENANT_CONFIG = REPO_ROOT / (
    'examples/deployments/platform/terragrunt/_global_settings/tenant.hcl'
)


def test_forge_module_ref_is_an_ordinary_caller_tag() -> None:
    tenant_config = TENANT_CONFIG.read_text(encoding='utf-8')
    module_variables = (MODULE / 'variables.tf').read_text(encoding='utf-8')

    assert (
        'forge_module_ref     = '
        'local.release_version.spec.iac.modules.forge_runners.ref'
    ) in tenant_config
    assert 'ForgeModuleRef          = local.forge_module_ref' in tenant_config
    assert 'forge_module_ref = local.forge_module_ref' not in tenant_config
    assert 'variable "forge_module_ref"' not in module_variables


def test_app_registry_application_receives_standard_tags() -> None:
    service_catalog = (MODULE / 'service_catalog.tf').read_text(
        encoding='utf-8'
    )
    expected_tags = (
        'tags = merge(\n'
        '    var.default_tags,\n'
        '    var.tags,\n'
        '  )'
    )
    assert expected_tags in service_catalog
