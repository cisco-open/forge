# Common tags we propagate project-wide.
locals {
  all_security_tags = merge(
    var.default_tags,
    var.tags,
    var.enable_app_registry ? aws_servicecatalogappregistry_application.this[0].application_tag : {},
  )
}
