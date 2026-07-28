resource "aws_servicecatalogappregistry_application" "this" {
  name = "helpers_service_linked_roles_${var.aws_region}"
  tags = merge(var.default_tags, var.tags)
}
