resource "aws_servicecatalogappregistry_application" "this" {
  name = "integrations_splunk_dependency_monitor_${var.aws_region}"
  tags = merge(var.default_tags, var.tags)
}
