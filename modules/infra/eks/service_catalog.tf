resource "aws_servicecatalogappregistry_application" "this" {
  name = "infra_eks_${var.aws_region}"
  tags = merge(var.default_tags, var.tags)
}
