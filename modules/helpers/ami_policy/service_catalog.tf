resource "aws_servicecatalogappregistry_application" "this" {
  name = "helpers_ami_policy_${var.aws_region}"
  tags = merge(var.default_tags, var.tags)
}
