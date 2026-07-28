resource "aws_servicecatalogappregistry_application" "this" {
  name = "integrations_splunk_cloud_data_manager_${var.aws_region}"
  tags = merge(var.default_tags, var.tags)
}
