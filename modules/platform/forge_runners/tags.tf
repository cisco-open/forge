# Common tags we propagate project-wide.
locals {
  deployment_version_tags = {
    ForgeModuleRef = var.forge_module_ref
  }

  all_security_tags = merge(
    var.default_tags,
    var.tags,
    local.deployment_version_tags,
    aws_servicecatalogappregistry_application.forge.application_tag
  )
}
