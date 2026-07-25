from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
MODULE = REPO_ROOT / 'modules/platform/forge_runners'


def test_forge_module_ref_is_propagated_as_a_non_overridable_tag() -> None:
    tags = (MODULE / 'tags.tf').read_text(encoding='utf-8')

    version_tag = 'ForgeModuleRef = var.forge_module_ref'
    assert version_tag in tags
    assert tags.index('local.deployment_version_tags,') > tags.index(
        'var.tags,'
    )
    assert tags.index('local.deployment_version_tags,') < tags.index(
        'aws_servicecatalogappregistry_application.forge.application_tag'
    )


def test_forge_core_exposes_the_deployed_module_ref() -> None:
    outputs = (MODULE / 'outputs.tf').read_text(encoding='utf-8')

    assert 'module_ref        = var.forge_module_ref' in outputs
