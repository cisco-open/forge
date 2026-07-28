resource "aws_servicecatalogappregistry_application" "this" {
  name = "helpers_opt_in_regions_${var.aws_region}"
  tags = var.default_tags
}
