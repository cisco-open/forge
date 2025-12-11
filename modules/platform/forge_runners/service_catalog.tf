resource "aws_servicecatalogappregistry_application" "forge" {
  name = var.deployment_config.deployment_prefix
}
