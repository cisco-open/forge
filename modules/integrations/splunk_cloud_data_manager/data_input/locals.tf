locals {
  name = data.external.splunk_dm_version.result.stack_name

  template_url = "https://${var.cloudformation_s3_config.bucket}.s3.amazonaws.com/${var.cloudformation_s3_config.key}${random_uuid.splunk_input_uuid.result}/${data.external.splunk_dm_version.result.template_hash}/template.json"

  tags = merge(
    var.tags_all,
    {
      SplunkDMVersion = data.external.splunk_dm_version.result["version"]
    }
  )
  tags_all = merge(
    var.tags_all,
    {
      SplunkDMVersion = data.external.splunk_dm_version.result["version"]
    }
  )
}
