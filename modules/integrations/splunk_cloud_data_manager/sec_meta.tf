locals {

  ds_sec = var.security_metadata_config.datasource

  dataset_info_security_metadata = merge(
    try(local.ds_sec.cloudtrail.enabled, false) ? { "cloudtrail" = {} } : {},
    try(local.ds_sec.securityhub.enabled, false) ? { "securityhub" = {} } : {},
    try(local.ds_sec.guardduty.enabled, false) ? { "guardduty" = {} } : {},
    try(local.ds_sec.iam-aa.enabled, false) ? { "iam-aa" = {} } : {},
    try(local.ds_sec.iam-cr.enabled, false) ? { "iam-cr" = {} } : {},
    try(local.ds_sec.metadata.enabled, false) ? {
      "metadata" = {
        "ec2-instances"     = {},
        "ec2-securitygroup" = {},
        "ec2-network-acls"  = {},
        "iam-users"         = {}
      }
    } : {}
  )

  details_security_metadata = merge(
    try(local.ds_sec.cloudtrail.enabled, false) ? { "cloudtrail" = local.ds_sec.cloudtrail.index } : {},
    try(local.ds_sec.securityhub.enabled, false) ? { "securityhub" = local.ds_sec.securityhub.index } : {},
    try(local.ds_sec.guardduty.enabled, false) ? { "guardduty" = local.ds_sec.guardduty.index } : {},
    try(local.ds_sec.iam-aa.enabled, false) ? { "iam-aa" = local.ds_sec.iam-aa.index } : {},
    try(local.ds_sec.iam-cr.enabled, false) ? { "iam-cr" = local.ds_sec.iam-cr.index } : {},
    try(local.ds_sec.metadata.enabled, false) ? { "metadata" = local.ds_sec.metadata.index } : {}
  )

  splunk_cloud_input_security_metadata_map = {
    name = var.security_metadata_config.name
    type = "AWS"
    destination = {
      type    = "index"
      details = local.details_security_metadata
    }
    mode = "Complete"
    details = {
      type         = "SingleAccount"
      iamRegion    = var.aws_region
      regions      = var.security_metadata_config.regions
      datasetInfo  = local.dataset_info_security_metadata
      dataAccounts = [var.aws_account_id]
      resourceTags = local.resource_tags
    }
  }
  splunk_cloud_input_security_metadata_json = jsonencode(local.splunk_cloud_input_security_metadata_map)

}

module "splunk_security_metadata" {
  providers = {
    aws = aws.cloudformation_s3_config
  }
  count  = var.security_metadata_config.enabled ? 1 : 0
  source = "./data_input"

  splunk_cloud             = var.splunk_cloud
  cloudformation_s3_config = var.cloudformation_s3_config
  splunk_cloud_input_json  = local.splunk_cloud_input_security_metadata_json

  tags     = local.all_security_tags
  tags_all = local.all_security_tags
}

resource "aws_cloudformation_stack" "cf_splunk_security_metadata_iam_region" {
  count = var.security_metadata_config.enabled ? 1 : 0
  name  = module.splunk_security_metadata[0].splunk_integration_name

  template_url = module.splunk_security_metadata[0].splunk_integration_template_url

  tags = module.splunk_security_metadata[0].splunk_integration_tags

  tags_all = module.splunk_security_metadata[0].splunk_integration_tags_all

  capabilities = [
    "CAPABILITY_NAMED_IAM"
  ]

  depends_on = [
    module.splunk_security_metadata,
  ]
}

resource "aws_cloudformation_stack" "cf_splunk_security_metadata_region" {
  for_each = var.security_metadata_config.enabled ? toset(setsubtract(var.security_metadata_config.regions, [var.aws_region])) : []
  provider = aws.by_region[each.value]
  name     = module.splunk_security_metadata[0].splunk_integration_name

  template_url = module.splunk_security_metadata[0].splunk_integration_template_url

  tags = module.splunk_security_metadata[0].splunk_integration_tags

  tags_all = module.splunk_security_metadata[0].splunk_integration_tags_all

  capabilities = [
    "CAPABILITY_NAMED_IAM"
  ]

  depends_on = [
    module.splunk_security_metadata,
    aws_cloudformation_stack.cf_splunk_security_metadata_iam_region
  ]
}

resource "null_resource" "splunk_dm_metadata_trigger" {
  triggers = {
    config_hash = md5(local.splunk_cloud_input_security_metadata_json)
  }

  depends_on = [
    module.splunk_security_metadata,
    aws_cloudformation_stack.cf_splunk_security_metadata_iam_region,
    aws_cloudformation_stack.cf_splunk_security_metadata_region,
  ]
}

data "aws_lambda_function" "splunk_dm_metadata_ec2inst" {
  for_each      = var.security_metadata_config.enabled ? toset(var.security_metadata_config.regions) : []
  provider      = aws.by_region[each.value]
  function_name = "SplunkDMMetadataEC2Inst"

  depends_on = [
    null_resource.splunk_dm_metadata_trigger
  ]
}

module "splunk_dm_metadata_ec2inst" {
  for_each = var.security_metadata_config.enabled ? toset(var.security_metadata_config.regions) : []
  providers = {
    aws = aws.by_region[each.value]
  }
  source = "./sec_meta_ec2_tags"

  region = each.value

  environment_variables = {
    SPLUNK_DATA_MANAGER_INPUT_ID = lookup(data.aws_lambda_function.splunk_dm_metadata_ec2inst[each.value].environment[0].variables,
      "SPLUNK_DATA_MANAGER_INPUT_ID",
      ""
    )
    SPLUNK_HEC_HOST = lookup(data.aws_lambda_function.splunk_dm_metadata_ec2inst[each.value].environment[0].variables,
      "SPLUNK_HEC_HOST",
      ""
    )
    SPLUNK_HEC_TOKEN = lookup(data.aws_lambda_function.splunk_dm_metadata_ec2inst[each.value].environment[0].variables,
      "SPLUNK_HEC_TOKEN",
      ""
    )
  }

  tags = module.splunk_security_metadata[0].splunk_integration_tags

  depends_on = [
    null_resource.splunk_dm_metadata_trigger
  ]
}
