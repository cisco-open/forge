resource "aws_servicecatalogappregistry_application" "this" {
  name = "helpers_aws_config_recording_${var.aws_region}"
  tags = merge(var.default_tags, var.tags)
}
