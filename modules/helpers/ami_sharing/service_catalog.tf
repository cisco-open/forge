resource "aws_servicecatalogappregistry_application" "this" {
  name = "helpers_ami_sharing_${var.aws_region}"
  tags = var.default_tags
}
