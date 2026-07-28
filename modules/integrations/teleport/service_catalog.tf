resource "aws_servicecatalogappregistry_application" "this" {
  name = "integrations_teleport_${var.aws_region}"
  tags = merge(var.default_tags, var.tags)
}
