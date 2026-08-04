locals {
  splunk_s3_logs_iam_region = trimspace(var.s3_logs_config.iam_region)

  splunk_cloud_input_s3_logs_map = {
    name = var.s3_logs_config.name
    type = "AWS"
    destination = {
      type = "index"
      details = {
        "s3-custom-logs" = var.s3_logs_config.index
      }
    }
    mode = "Complete"
    details = {
      type      = "SingleAccount"
      iamRegion = local.splunk_s3_logs_iam_region
      datasetInfo = {
        "s3-custom-logs" = {
          sqsUrls = [
            for sqs_url in var.s3_logs_config.sqs_urls : {
              sqsUrl = sqs_url
            }
          ]
          sourceType = var.s3_logs_config.source_type
        }
      }
      dataAccounts     = [data.aws_caller_identity.current.account_id]
      s3BucketPatterns = var.s3_logs_config.s3_bucket_patterns
      kmsKeyArns       = var.s3_logs_config.kms_key_arns
    }
  }

  splunk_cloud_input_s3_logs_json = jsonencode(local.splunk_cloud_input_s3_logs_map)
}

module "splunk_s3_logs" {
  providers = {
    aws = aws.cloudformation_s3_config
  }
  count  = var.s3_logs_config.enabled ? 1 : 0
  source = "./data_input"

  splunk_cloud             = var.splunk_cloud
  cloudformation_s3_config = var.cloudformation_s3_config
  splunk_cloud_input_json  = local.splunk_cloud_input_s3_logs_json

  tags_all = local.all_security_tags
}

resource "aws_cloudformation_stack" "cf_splunk_s3_logs_iam_region" {
  #checkov:skip=CKV_AWS_124:Splunk-managed CloudFormation template is provided by a trusted entity; SNS notifications are not required for this module.
  count    = var.s3_logs_config.enabled ? 1 : 0
  provider = aws.s3_logs_iam_region
  name     = module.splunk_s3_logs[0].splunk_integration_name

  template_url = module.splunk_s3_logs[0].splunk_integration_template_url

  tags = module.splunk_s3_logs[0].splunk_integration_tags

  tags_all = module.splunk_s3_logs[0].splunk_integration_tags_all

  capabilities = [
    "CAPABILITY_NAMED_IAM"
  ]

  lifecycle {
    precondition {
      condition = alltrue([
        for sqs_url in var.s3_logs_config.sqs_urls :
        try(split("/", trimspace(sqs_url))[3], "") == data.aws_caller_identity.current.account_id
      ])
      error_message = "Every S3 logs SQS queue must belong to the current AWS account."
    }
  }

  depends_on = [
    module.splunk_s3_logs,
  ]
}
