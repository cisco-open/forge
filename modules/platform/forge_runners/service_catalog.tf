resource "aws_servicecatalogappregistry_application" "forge" {
  name = var.deployment_config.deployment_prefix
  tags = merge(
    var.default_tags,
    var.tags,
    local.deployment_version_tags,
  )
}
