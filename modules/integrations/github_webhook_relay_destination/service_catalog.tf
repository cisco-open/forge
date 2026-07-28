resource "aws_servicecatalogappregistry_application" "this" {
  name = "integrations_github_webhook_relay_destination_${var.aws_region}"
  tags = merge(var.default_tags, var.tags)
}
