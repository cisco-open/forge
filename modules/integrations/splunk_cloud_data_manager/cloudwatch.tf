locals {

  ds_cloudwatch = var.cloudwatch_log_groups_config.datasource

  dataset_info_cloudwatch = merge(
    try(local.ds_cloudwatch.cwl-api-gateway.enabled, false) ? { "cwl-api-gateway" = {} } : {},
    try(local.ds_cloudwatch.cwl-cloudhsm.enabled, false) ? { "cwl-cloudhsm" = {} } : {},
    try(local.ds_cloudwatch.cwl-documentDB.enabled, false) ? { "cwl-documentDB" = {} } : {},
    try(local.ds_cloudwatch.cwl-eks.enabled, false) ? { "cwl-eks" = {} } : {},
    try(local.ds_cloudwatch.cwl-lambda.enabled, false) ? { "cwl-lambda" = {} } : {},
    try(local.ds_cloudwatch.cwl-rds.enabled, false) ? { "cwl-rds" = {} } : {},
    try(local.ds_cloudwatch.cwl-vpc-flow-logs.enabled, false) ? { "cwl-vpc-flow-logs" = { vpcIds = local.ds_cloudwatch.cwl-vpc-flow-logs.vpcIds } } : {},
  )

  details_cloudwatch = merge(
    try(local.ds_cloudwatch.cwl-api-gateway.enabled, false) ? { "cwl-api-gateway" = local.ds_cloudwatch.cwl-api-gateway.index } : {},
    try(local.ds_cloudwatch.cwl-cloudhsm.enabled, false) ? { "cwl-cloudhsm" = local.ds_cloudwatch.cwl-cloudhsm.index } : {},
    try(local.ds_cloudwatch.cwl-documentDB.enabled, false) ? { "cwl-documentDB" = local.ds_cloudwatch.cwl-documentDB.index } : {},
    try(local.ds_cloudwatch.cwl-eks.enabled, false) ? { "cwl-eks" = local.ds_cloudwatch.cwl-eks.index } : {},
    try(local.ds_cloudwatch.cwl-lambda.enabled, false) ? { "cwl-lambda" = local.ds_cloudwatch.cwl-lambda.index } : {},
    try(local.ds_cloudwatch.cwl-rds.enabled, false) ? { "cwl-rds" = local.ds_cloudwatch.cwl-rds.index } : {},
    try(local.ds_cloudwatch.cwl-vpc-flow-logs.enabled, false) ? { "cwl-vpc-flow-logs" = local.ds_cloudwatch.cwl-vpc-flow-logs.index } : {},
  )

  splunk_cloud_input_cloudwatch_map = {
    name = var.cloudwatch_log_groups_config.name
    type = "AWS"
    destination = {
      type    = "index"
      details = local.details_cloudwatch
    }
    mode = "Complete"
    details = {
      type         = "SingleAccount"
      iamRegion    = var.aws_region
      regions      = var.cloudwatch_log_groups_config.regions
      datasetInfo  = local.dataset_info_cloudwatch
      dataAccounts = [var.aws_account_id]
      resourceTags = local.resource_tags
    }
  }
  splunk_cloud_input_cloudwatch_json = jsonencode(local.splunk_cloud_input_cloudwatch_map)
}

module "splunk_cloudwatch" {
  providers = {
    aws = aws.cloudformation_s3_config
  }
  count  = var.cloudwatch_log_groups_config.enabled ? 1 : 0
  source = "./data_input"

  splunk_cloud             = var.splunk_cloud
  cloudformation_s3_config = var.cloudformation_s3_config
  splunk_cloud_input_json  = local.splunk_cloud_input_cloudwatch_json

  tags     = local.all_security_tags
  tags_all = local.all_security_tags
}

resource "aws_cloudformation_stack" "cf_splunk_cloudwatch_iam_region" {
  count = var.cloudwatch_log_groups_config.enabled ? 1 : 0
  name  = module.splunk_cloudwatch[0].splunk_integration_name

  template_url = module.splunk_cloudwatch[0].splunk_integration_template_url

  tags = module.splunk_cloudwatch[0].splunk_integration_tags

  tags_all = module.splunk_cloudwatch[0].splunk_integration_tags_all

  capabilities = [
    "CAPABILITY_NAMED_IAM"
  ]

  depends_on = [
    module.splunk_cloudwatch
  ]
}

resource "aws_cloudformation_stack" "cf_splunk_cloudwatch_region" {
  for_each = var.cloudwatch_log_groups_config.enabled ? toset(setsubtract(var.cloudwatch_log_groups_config.regions, [var.aws_region])) : []
  provider = aws.by_region[each.value]
  name     = module.splunk_cloudwatch[0].splunk_integration_name

  template_url = module.splunk_cloudwatch[0].splunk_integration_template_url

  tags = module.splunk_cloudwatch[0].splunk_integration_tags

  tags_all = module.splunk_cloudwatch[0].splunk_integration_tags_all

  capabilities = [
    "CAPABILITY_NAMED_IAM"
  ]

  depends_on = [
    module.splunk_cloudwatch,
    aws_cloudformation_stack.cf_splunk_cloudwatch_iam_region
  ]
}
