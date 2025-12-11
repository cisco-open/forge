data "aws_cloudwatch_log_groups" "log_groups" {
  for_each = {
    for idx, log_group in var.custom_cloudwatch_log_groups_config.log_group_name_prefixes :
    "${idx}_${log_group.region}" => log_group
  }
  provider              = aws.by_region[each.value.region]
  log_group_name_prefix = each.value.log_group_name_prefix
}

locals {

  initial_custom_log_group_names = {
    for k, v in data.aws_cloudwatch_log_groups.log_groups :
    replace(k, "/^[0-9]+_/", "") => v.log_group_names...
  }

  custom_log_group_names = {
    for k, v in local.initial_custom_log_group_names :
    k => flatten(v)
  }

  custom_log_group_regions = distinct([
    for v in var.custom_cloudwatch_log_groups_config.log_group_name_prefixes :
    v.region
  ])

  splunk_cloud_input_custom_logs_map = {
    name = var.custom_cloudwatch_log_groups_config.name
    type = "AWS"
    destination = {
      type = "index"
      details = {
        "cwl-custom-logs" = var.custom_cloudwatch_log_groups_config.index
      }
    }
    mode = "Complete"
    details = {
      type      = "SingleAccount"
      iamRegion = var.aws_region
      regions   = local.custom_log_group_regions
      datasetInfo = {
        "cwl-custom-logs" = {
          sourceType = "aws:cloudwatchlogs:${var.custom_cloudwatch_log_groups_config.source_type}"
          logGroups = {
            names = local.custom_log_group_names
          }
        }
      }
      dataAccounts = [data.aws_caller_identity.current.account_id]
      resourceTags = local.resource_tags
    }
  }

  splunk_cloud_input_custom_logs_json = jsonencode(local.splunk_cloud_input_custom_logs_map)
}
module "splunk_custom_cloudwatch" {
  providers = {
    aws = aws.cloudformation_s3_config
  }
  count  = var.custom_cloudwatch_log_groups_config.enabled ? 1 : 0
  source = "./data_input"

  splunk_cloud             = var.splunk_cloud
  cloudformation_s3_config = var.cloudformation_s3_config
  splunk_cloud_input_json  = local.splunk_cloud_input_custom_logs_json

  tags     = local.all_security_tags
  tags_all = local.all_security_tags
}

resource "aws_cloudformation_stack" "cf_splunk_custom_cloudwatch_iam_region" {
  count = var.custom_cloudwatch_log_groups_config.enabled ? 1 : 0
  name  = module.splunk_custom_cloudwatch[0].splunk_integration_name

  template_url = module.splunk_custom_cloudwatch[0].splunk_integration_template_url

  tags = module.splunk_custom_cloudwatch[0].splunk_integration_tags

  tags_all = module.splunk_custom_cloudwatch[0].splunk_integration_tags_all

  capabilities = [
    "CAPABILITY_NAMED_IAM"
  ]

  depends_on = [
    module.splunk_custom_cloudwatch
  ]
}

resource "aws_cloudformation_stack" "cf_splunk_custom_cloudwatch_region" {
  for_each = var.custom_cloudwatch_log_groups_config.enabled ? toset(setsubtract(local.custom_log_group_regions, [var.aws_region])) : []
  provider = aws.by_region[each.key]
  name     = module.splunk_custom_cloudwatch[0].splunk_integration_name

  template_url = module.splunk_custom_cloudwatch[0].splunk_integration_template_url

  tags = module.splunk_custom_cloudwatch[0].splunk_integration_tags

  tags_all = module.splunk_custom_cloudwatch[0].splunk_integration_tags_all

  capabilities = [
    "CAPABILITY_NAMED_IAM"
  ]

  depends_on = [
    module.splunk_custom_cloudwatch,
    aws_cloudformation_stack.cf_splunk_custom_cloudwatch_iam_region
  ]
}
