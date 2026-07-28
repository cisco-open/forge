resource "aws_servicecatalogappregistry_application" "this" {
  name = "integrations_splunk_o11y_aws_integration_${var.aws_region}"
  tags = merge(var.default_tags, var.tags)
}
