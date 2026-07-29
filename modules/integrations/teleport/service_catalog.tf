resource "aws_servicecatalogappregistry_application" "this" {
  name = "integrations_teleport_${var.teleport_config.cluster_name}_${var.aws_region}"
  tags = merge(var.default_tags, var.tags)
}
