# Common tags we propagate project-wide.
locals {
  all_security_tags = merge(
    var.default_tags,
    var.tags,
    aws_servicecatalogappregistry_application.this.application_tag,
  )
  iam_role_name = coalesce(var.iam_role_name, "forge-aws-config-recorder-${var.aws_region}")
}
