locals {
  config_aliases = compact([
    var.custom_cloudwatch_log_groups_config.enabled ? "custom-cwl" : "",
    var.cloudwatch_log_groups_config.enabled ? "cwl" : "",
    length(local.splunk_s3_logs_inputs) > 0 ? "s3-logs" : "",
    var.security_metadata_config.enabled ? "secmeta" : "",
  ])
}

resource "aws_servicecatalogappregistry_application" "this" {
  name = join("_", concat(
    ["integrations_splunk_cloud_data_manager"],
    local.config_aliases,
    [var.aws_region],
  ))
  tags = merge(var.default_tags, var.tags)
}
