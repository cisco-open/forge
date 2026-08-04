mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "166060576821"
      arn        = "arn:aws:iam::166060576821:user/test"
      user_id    = "test"
    }
  }

  mock_data "aws_secretsmanager_secret" {
    defaults = {
      id = "/cicd/common/splunk-cloud"
    }
  }

  mock_data "aws_secretsmanager_secret_version" {
    defaults = {
      secret_string = "mock-splunk-secret"
    }
  }
}

mock_provider "aws" {
  alias = "cloudformation_s3_config"

  mock_data "aws_secretsmanager_secret" {
    defaults = {
      id = "/cicd/common/splunk-cloud"
    }
  }

  mock_data "aws_secretsmanager_secret_version" {
    defaults = {
      secret_string = "mock-splunk-secret"
    }
  }
}

mock_provider "aws" {
  alias = "s3_logs_iam_region"
}

mock_provider "aws" {
  alias = "by_region"
}

mock_provider "external" {
  mock_data "external" {
    defaults = {
      result = {
        version       = "1"
        template_hash = "template-sha"
        stack_name    = "SplunkDMSqsS3-00000000-0000-0000-0000-000000000001"
      }
    }
  }
}

mock_provider "random" {
  mock_resource "random_uuid" {
    defaults = {
      result = "00000000-0000-0000-0000-000000000001"
    }
  }
}

mock_provider "null" {}
mock_provider "local" {}
mock_provider "time" {}

variables {
  aws_profile  = "test"
  aws_region   = "eu-west-1"
  splunk_cloud = "https://splunk.example.com"
  cloudformation_s3_config = {
    bucket = "forge-templates"
    key    = "splunk/"
    region = "eu-west-1"
  }
  s3_logs_config = {
    enabled     = true
    name        = "forge-s3-logs"
    iam_region  = "us-east-1"
    index       = "srea-forge-nonprod-index"
    source_type = "forgecicd:runner-logs:s3"
    sqs_urls = [
      "https://sqs.eu-west-1.amazonaws.com/166060576821/splunk-s3-runner-logs-events",
      "https://sqs.us-east-2.amazonaws.com/166060576821/splunk-s3-audit-logs-events",
    ]
    s3_bucket_patterns = [
      "acgw-usw2-sl-forge-gh-logs-*",
      "*",
    ]
    kms_key_arns = [
      "arn:aws:kms:us-west-2:166060576821:key/11111111-1111-1111-1111-111111111111",
      "arn:aws:kms:us-east-2:166060576821:key/22222222-2222-2222-2222-222222222222",
    ]
  }
  default_tags = {
    Product = "Forge"
  }
  tags = {
    Env = "test"
  }
}

run "s3_logs_request_contract" {
  command = plan

  assert {
    condition = (
      jsondecode(output.splunk_cloud_input_s3_logs_json).name == "forge-s3-logs"
      && jsondecode(output.splunk_cloud_input_s3_logs_json).type == "AWS"
      && jsondecode(output.splunk_cloud_input_s3_logs_json).destination.type == "index"
      && jsondecode(output.splunk_cloud_input_s3_logs_json).destination.details["s3-custom-logs"] == "srea-forge-nonprod-index"
      && jsondecode(output.splunk_cloud_input_s3_logs_json).mode == "Complete"
    )
    error_message = "The S3 logs input must preserve the Data Manager input identity, AWS type, index destination, and complete mode."
  }

  assert {
    condition = (
      jsondecode(output.splunk_cloud_input_s3_logs_json).details.type == "SingleAccount"
      && jsondecode(output.splunk_cloud_input_s3_logs_json).details.iamRegion == "us-east-1"
      && jsondecode(output.splunk_cloud_input_s3_logs_json).details.dataAccounts == ["166060576821"]
      && jsondecode(output.splunk_cloud_input_s3_logs_json).details.datasetInfo["s3-custom-logs"].sourceType == "forgecicd:runner-logs:s3"
      && jsondecode(output.splunk_cloud_input_s3_logs_json).details.datasetInfo["s3-custom-logs"].sqsUrls == [
        { sqsUrl = "https://sqs.eu-west-1.amazonaws.com/166060576821/splunk-s3-runner-logs-events" },
        { sqsUrl = "https://sqs.us-east-2.amazonaws.com/166060576821/splunk-s3-audit-logs-events" },
      ]
    )
    error_message = "The S3 logs input must wrap every queue URL for the s3-custom-logs dataset and use the current AWS account and IAM region."
  }

  assert {
    condition = (
      jsondecode(output.splunk_cloud_input_s3_logs_json).details.s3BucketPatterns == [
        "acgw-usw2-sl-forge-gh-logs-*",
        "*",
      ]
      && jsondecode(output.splunk_cloud_input_s3_logs_json).details.kmsKeyArns == [
        "arn:aws:kms:us-west-2:166060576821:key/11111111-1111-1111-1111-111111111111",
        "arn:aws:kms:us-east-2:166060576821:key/22222222-2222-2222-2222-222222222222",
      ]
      && !contains(keys(jsondecode(output.splunk_cloud_input_s3_logs_json).details), "regions")
      && !contains(keys(jsondecode(output.splunk_cloud_input_s3_logs_json).details), "resourceTags")
    )
    error_message = "The S3 logs input must preserve bucket and KMS lists without adding push-based CloudWatch fields."
  }

  assert {
    condition = (
      length(aws_cloudformation_stack.cf_splunk_s3_logs_iam_region) == 1
      && aws_cloudformation_stack.cf_splunk_s3_logs_iam_region[0].capabilities == toset(["CAPABILITY_NAMED_IAM"])
    )
    error_message = "The S3 logs input must create one IAM-region CloudFormation stack with named-IAM capability."
  }
}

run "s3_logs_custom_iam_region_contract" {
  command = plan

  variables {
    s3_logs_config = {
      enabled     = true
      name        = "forge-s3-logs"
      iam_region  = " eu-central-1 "
      index       = "srea-forge-nonprod-index"
      source_type = "forgecicd:runner-logs:s3"
      sqs_urls = [
        "https://sqs.eu-west-1.amazonaws.com/166060576821/splunk-s3-runner-logs-events",
      ]
      s3_bucket_patterns = [
        "forge-runner-logs-*",
      ]
      kms_key_arns = []
    }
  }

  assert {
    condition     = jsondecode(output.splunk_cloud_input_s3_logs_json).details.iamRegion == "eu-central-1"
    error_message = "The S3 logs input must use its configured IAM roles region independently of queue and module regions."
  }
}

run "s3_logs_rejects_foreign_queue_account" {
  command = plan

  variables {
    s3_logs_config = {
      enabled     = true
      name        = "forge-s3-logs"
      iam_region  = "us-east-1"
      index       = "srea-forge-nonprod-index"
      source_type = "forgecicd:runner-logs:s3"
      sqs_urls = [
        "https://sqs.eu-west-1.amazonaws.com/999999999999/foreign-account-events",
      ]
      s3_bucket_patterns = [
        "forge-runner-logs-*",
      ]
      kms_key_arns = []
    }
  }

  expect_failures = [
    aws_cloudformation_stack.cf_splunk_s3_logs_iam_region,
  ]
}

run "s3_logs_empty_kms_contract" {
  command = plan

  variables {
    s3_logs_config = {
      enabled     = true
      name        = "forge-s3-logs"
      index       = "srea-forge-nonprod-index"
      source_type = "forgecicd:runner-logs:s3"
      sqs_urls = [
        "https://sqs.eu-west-1.amazonaws.com/166060576821/splunk-s3-runner-logs-events",
      ]
      s3_bucket_patterns = [
        "arn:aws:s3:::acgw-usw2-sl-forge-gh-logs-166060576821",
      ]
      kms_key_arns = []
    }
  }

  assert {
    condition     = jsondecode(output.splunk_cloud_input_s3_logs_json).details.kmsKeyArns == []
    error_message = "The S3 logs input must allow and serialize an empty KMS key ARN list."
  }
}

run "s3_logs_disabled_contract" {
  command = plan

  variables {
    s3_logs_config = {
      enabled            = false
      name               = ""
      index              = ""
      source_type        = ""
      sqs_urls           = []
      s3_bucket_patterns = []
      kms_key_arns       = []
    }
  }

  assert {
    condition = (
      output.splunk_cloud_input_s3_logs_json == ""
      && length(aws_cloudformation_stack.cf_splunk_s3_logs_iam_region) == 0
    )
    error_message = "A disabled S3 logs input must emit no request JSON and create no CloudFormation stack."
  }
}

run "s3_logs_required_sources_contract" {
  command = plan

  variables {
    s3_logs_config = {
      enabled            = true
      name               = "forge-s3-logs"
      index              = "srea-forge-nonprod-index"
      source_type        = "forgecicd:runner-logs:s3"
      sqs_urls           = []
      s3_bucket_patterns = []
      kms_key_arns       = []
    }
  }

  expect_failures = [
    var.s3_logs_config,
  ]
}

run "s3_logs_rejects_non_regional_sqs_url" {
  command = plan

  variables {
    s3_logs_config = {
      enabled     = true
      name        = "forge-s3-logs"
      index       = "srea-forge-nonprod-index"
      source_type = "forgecicd:runner-logs:s3"
      sqs_urls = [
        "https://example.com/not-an-sqs-queue",
      ]
      s3_bucket_patterns = [
        "arn:aws:s3:::acgw-usw2-sl-forge-gh-logs-166060576821",
      ]
      kms_key_arns = []
    }
  }

  expect_failures = [
    var.s3_logs_config,
  ]
}
