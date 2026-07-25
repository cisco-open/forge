# Common tags we propagate project-wide.
locals {
  all_security_tags = merge(
    var.default_tags,
    var.tags,
    aws_servicecatalogappregistry_application.forge.application_tag
  )
}
