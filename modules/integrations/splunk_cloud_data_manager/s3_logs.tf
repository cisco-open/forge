locals {
  splunk_s3_logs_by_dataset = {
    "s3-custom-logs"  = var.s3_logs_config["s3-custom-logs"]
    "ct-logs"         = var.s3_logs_config["ct-logs"]
    "s3-access-logs"  = var.s3_logs_config["s3-access-logs"]
    "elb-access-logs" = var.s3_logs_config["elb-access-logs"]
    "cf-access-logs"  = var.s3_logs_config["cf-access-logs"]
  }

  splunk_s3_logs_all_inputs = flatten([
    for dataset, configs in local.splunk_s3_logs_by_dataset : [
      for config in configs : {
        dataset            = dataset
        enabled            = config.enabled
        name               = trimspace(config.name)
        iam_region         = trimspace(config.iam_region)
        index              = trimspace(config.index)
        source_type        = try(trimspace(config.source_type), "")
        sqs_urls           = [for value in config.sqs_urls : trimspace(value)]
        s3_bucket_patterns = [for value in config.s3_bucket_patterns : trimspace(value)]
        kms_key_arns       = [for value in config.kms_key_arns : trimspace(value)]
      }
    ]
  ])

  splunk_s3_logs_inputs_by_name = {
    for config in local.splunk_s3_logs_all_inputs :
    config.name => config... if config.enabled
  }

  splunk_s3_logs_inputs = {
    for input_name, configs in local.splunk_s3_logs_inputs_by_name :
    input_name => configs[0]
  }

  splunk_s3_logs_dataset_info = {
    for input_name, config in local.splunk_s3_logs_inputs :
    input_name => merge(
      {
        sqsUrls = [
          for sqs_url in config.sqs_urls : {
            sqsUrl = sqs_url
          }
        ]
      },
      config.dataset == "s3-custom-logs" ? {
        sourceType = config.source_type
      } : {},
    )
  }

  splunk_cloud_input_s3_logs_maps = {
    for input_name, config in local.splunk_s3_logs_inputs :
    input_name => {
      name = config.name
      type = "AWS"
      destination = {
        type = "index"
        details = {
          (config.dataset) = config.index
        }
      }
      mode = "Complete"
      details = {
        type      = "SingleAccount"
        iamRegion = config.iam_region
        datasetInfo = {
          (config.dataset) = local.splunk_s3_logs_dataset_info[input_name]
        }
        dataAccounts     = [data.aws_caller_identity.current.account_id]
        s3BucketPatterns = config.s3_bucket_patterns
        kmsKeyArns       = config.kms_key_arns
      }
    }
  }

  splunk_cloud_input_s3_logs_json = {
    for input_name, payload in local.splunk_cloud_input_s3_logs_maps :
    input_name => jsonencode(payload)
  }
}

module "splunk_s3_logs" {
  providers = {
    aws = aws.cloudformation_s3_config
  }
  for_each = local.splunk_cloud_input_s3_logs_json
  source   = "./data_input"

  splunk_cloud             = var.splunk_cloud
  cloudformation_s3_config = var.cloudformation_s3_config
  splunk_cloud_input_json  = each.value
  stack_name_prefix        = "SplunkDMSqsS3"

  tags_all = local.all_security_tags
}

resource "aws_cloudformation_stack" "cf_splunk_s3_logs_iam_region" {
  #checkov:skip=CKV_AWS_124:Splunk-managed CloudFormation template is provided by a trusted entity; SNS notifications are not required for this module.
  for_each = local.splunk_s3_logs_inputs
  region   = each.value.iam_region
  name     = module.splunk_s3_logs[each.key].splunk_integration_name

  template_url = module.splunk_s3_logs[each.key].splunk_integration_template_url

  tags = module.splunk_s3_logs[each.key].splunk_integration_tags

  tags_all = module.splunk_s3_logs[each.key].splunk_integration_tags_all

  capabilities = [
    "CAPABILITY_NAMED_IAM"
  ]

  depends_on = [
    module.splunk_s3_logs
  ]

  lifecycle {
    precondition {
      condition = alltrue([
        for sqs_url in each.value.sqs_urls :
        try(split("/", trimspace(sqs_url))[3], "") == data.aws_caller_identity.current.account_id
      ])
      error_message = "Every S3 logs SQS queue must belong to the current AWS account."
    }
  }
}
