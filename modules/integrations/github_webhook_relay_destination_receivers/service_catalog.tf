resource "aws_servicecatalogappregistry_application" "this" {
  name = "integrations_github_webhook_relay_destination_receivers_${var.aws_region}"
  tags = merge(var.default_tags, var.tags)
}

locals {
  module_tags = merge(
    var.tags,
    aws_servicecatalogappregistry_application.this.application_tag,
  )
}
