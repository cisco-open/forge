resource "aws_servicecatalogappregistry_application" "this" {
  count = var.enable_app_registry ? 1 : 0
  name  = "integrations_splunk_o11y_aws_integration_${var.aws_region}"
  tags  = merge(var.default_tags, var.tags)
}
