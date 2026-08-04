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
    "s3-custom-logs" = [
      {
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
      },
    ]
  }
  default_tags = {
    Product = "Forge"
  }
  tags = {
    Env = "test"
  }
}

run "s3_custom_logs_request_contract" {
  command = plan

  assert {
    condition = (
      length(output.splunk_cloud_input_s3_logs_json) == 1
      && contains(keys(output.splunk_cloud_input_s3_logs_json), "forge-s3-logs")
      && jsondecode(output.splunk_cloud_input_s3_logs_json["forge-s3-logs"]).name == "forge-s3-logs"
      && jsondecode(output.splunk_cloud_input_s3_logs_json["forge-s3-logs"]).type == "AWS"
      && jsondecode(output.splunk_cloud_input_s3_logs_json["forge-s3-logs"]).destination.type == "index"
      && jsondecode(output.splunk_cloud_input_s3_logs_json["forge-s3-logs"]).destination.details["s3-custom-logs"] == "srea-forge-nonprod-index"
      && jsondecode(output.splunk_cloud_input_s3_logs_json["forge-s3-logs"]).mode == "Complete"
    )
    error_message = "The custom S3 input must preserve its name, AWS type, destination, and complete mode."
  }

  assert {
    condition = (
      jsondecode(output.splunk_cloud_input_s3_logs_json["forge-s3-logs"]).details.type == "SingleAccount"
      && jsondecode(output.splunk_cloud_input_s3_logs_json["forge-s3-logs"]).details.iamRegion == "us-east-1"
      && jsondecode(output.splunk_cloud_input_s3_logs_json["forge-s3-logs"]).details.dataAccounts == ["166060576821"]
      && jsondecode(output.splunk_cloud_input_s3_logs_json["forge-s3-logs"]).details.datasetInfo["s3-custom-logs"] == {
        sourceType = "forgecicd:runner-logs:s3"
        sqsUrls = [
          { sqsUrl = "https://sqs.eu-west-1.amazonaws.com/166060576821/splunk-s3-runner-logs-events" },
          { sqsUrl = "https://sqs.us-east-2.amazonaws.com/166060576821/splunk-s3-audit-logs-events" },
        ]
      }
    )
    error_message = "The custom S3 input must emit sourceType and wrap every configured queue URL."
  }

  assert {
    condition = (
      jsondecode(output.splunk_cloud_input_s3_logs_json["forge-s3-logs"]).details.s3BucketPatterns == [
        "acgw-usw2-sl-forge-gh-logs-*",
        "*",
      ]
      && jsondecode(output.splunk_cloud_input_s3_logs_json["forge-s3-logs"]).details.kmsKeyArns == [
        "arn:aws:kms:us-west-2:166060576821:key/11111111-1111-1111-1111-111111111111",
        "arn:aws:kms:us-east-2:166060576821:key/22222222-2222-2222-2222-222222222222",
      ]
      && !contains(keys(jsondecode(output.splunk_cloud_input_s3_logs_json["forge-s3-logs"]).details), "regions")
      && !contains(keys(jsondecode(output.splunk_cloud_input_s3_logs_json["forge-s3-logs"]).details), "resourceTags")
      && length(aws_cloudformation_stack.cf_splunk_s3_logs_iam_region) == 1
      && aws_cloudformation_stack.cf_splunk_s3_logs_iam_region["forge-s3-logs"].capabilities == toset(["CAPABILITY_NAMED_IAM"])
    )
    error_message = "Each enabled S3 input must create one named-IAM CloudFormation stack."
  }
}

run "s3_all_datasets_request_contract" {
  command = plan

  variables {
    s3_logs_config = {
      "s3-custom-logs" = [
        {
          enabled            = true
          name               = "forge-custom"
          iam_region         = "us-east-1"
          index              = "srea-forge-nonprod-index"
          source_type        = "forgecicd:custom:s3"
          sqs_urls           = ["https://sqs.us-east-1.amazonaws.com/166060576821/custom-events"]
          s3_bucket_patterns = ["custom*"]
          kms_key_arns       = []
        },
      ]
      "ct-logs" = [
        {
          enabled            = true
          name               = "forge-cloudtrail"
          iam_region         = "us-east-1"
          index              = "srea-forge-nonprod-index"
          sqs_urls           = ["https://sqs.us-west-2.amazonaws.com/166060576821/cloudtrail-events"]
          s3_bucket_patterns = ["cloudtrail*"]
          kms_key_arns       = []
        },
      ]
      "s3-access-logs" = [
        {
          enabled            = true
          name               = "forge-s3-access"
          iam_region         = "eu-west-1"
          index              = "srea-forge-nonprod-index"
          sqs_urls           = ["https://sqs.us-east-1.amazonaws.com/166060576821/s3-access-events"]
          s3_bucket_patterns = ["s3access*"]
          kms_key_arns       = []
        },
      ]
      "elb-access-logs" = [
        {
          enabled            = true
          name               = "forge-elb-access"
          iam_region         = "us-east-1"
          index              = "srea-forge-nonprod-index"
          sqs_urls           = ["https://sqs.us-west-2.amazonaws.com/166060576821/elb-access-events"]
          s3_bucket_patterns = ["elbaccess*"]
          kms_key_arns       = []
        },
      ]
      "cf-access-logs" = [
        {
          enabled            = true
          name               = "forge-cloudfront-access"
          iam_region         = "us-east-1"
          index              = "srea-forge-nonprod-index"
          sqs_urls           = ["https://sqs.us-east-1.amazonaws.com/166060576821/cloudfront-access-events"]
          s3_bucket_patterns = ["cloudfront*"]
          kms_key_arns       = []
        },
      ]
    }
  }

  assert {
    condition = (
      toset(keys(output.splunk_cloud_input_s3_logs_json)) == toset([
        "forge-custom",
        "forge-cloudtrail",
        "forge-s3-access",
        "forge-elb-access",
        "forge-cloudfront-access",
      ])
      && length(aws_cloudformation_stack.cf_splunk_s3_logs_iam_region) == 5
      && aws_cloudformation_stack.cf_splunk_s3_logs_iam_region["forge-cloudtrail"].region == "us-east-1"
      && aws_cloudformation_stack.cf_splunk_s3_logs_iam_region["forge-s3-access"].region == "eu-west-1"
    )
    error_message = "Every enabled dataset list item must create an independent stack in its configured IAM region."
  }

  assert {
    condition = alltrue([
      for item in [
        { name = "forge-cloudtrail", dataset = "ct-logs" },
        { name = "forge-s3-access", dataset = "s3-access-logs" },
        { name = "forge-elb-access", dataset = "elb-access-logs" },
        { name = "forge-cloudfront-access", dataset = "cf-access-logs" },
        ] : (
        keys(jsondecode(output.splunk_cloud_input_s3_logs_json[item.name]).destination.details) == [item.dataset]
        && keys(jsondecode(output.splunk_cloud_input_s3_logs_json[item.name]).details.datasetInfo) == [item.dataset]
        && !contains(keys(jsondecode(output.splunk_cloud_input_s3_logs_json[item.name]).details.datasetInfo[item.dataset]), "sourceType")
      )
    ])
    error_message = "Predefined S3 inputs must use their selected dataset key and omit sourceType."
  }

  assert {
    condition     = jsondecode(output.splunk_cloud_input_s3_logs_json["forge-custom"]).details.datasetInfo["s3-custom-logs"].sourceType == "forgecicd:custom:s3"
    error_message = "Custom S3 inputs must retain their configured source_type alongside predefined inputs."
  }
}

run "s3_logs_multiple_inputs_per_dataset_contract" {
  command = plan

  variables {
    s3_logs_config = {
      "ct-logs" = [
        {
          enabled            = true
          name               = "forge-cloudtrail-east"
          iam_region         = "us-east-1"
          index              = "forge-east-index"
          sqs_urls           = ["https://sqs.us-east-1.amazonaws.com/166060576821/cloudtrail-east"]
          s3_bucket_patterns = ["east*"]
          kms_key_arns       = []
        },
        {
          enabled            = true
          name               = "forge-cloudtrail-west"
          iam_region         = "us-west-2"
          index              = "forge-west-index"
          sqs_urls           = ["https://sqs.us-west-2.amazonaws.com/166060576821/cloudtrail-west"]
          s3_bucket_patterns = ["west*"]
          kms_key_arns       = []
        },
      ]
    }
  }

  assert {
    condition = (
      length(output.splunk_cloud_input_s3_logs_json) == 2
      && jsondecode(output.splunk_cloud_input_s3_logs_json["forge-cloudtrail-east"]).destination.details["ct-logs"] == "forge-east-index"
      && jsondecode(output.splunk_cloud_input_s3_logs_json["forge-cloudtrail-west"]).destination.details["ct-logs"] == "forge-west-index"
    )
    error_message = "A dataset list must support multiple independent Data Manager inputs."
  }
}

run "s3_logs_reordered_inputs_keep_identity_keys" {
  command = plan

  variables {
    s3_logs_config = {
      "ct-logs" = [
        {
          enabled            = true
          name               = "forge-cloudtrail-west"
          iam_region         = "us-west-2"
          index              = "forge-west-index"
          sqs_urls           = ["https://sqs.us-west-2.amazonaws.com/166060576821/cloudtrail-west"]
          s3_bucket_patterns = ["west*"]
          kms_key_arns       = []
        },
        {
          enabled            = true
          name               = "forge-cloudtrail-east"
          iam_region         = "us-east-1"
          index              = "forge-east-index"
          sqs_urls           = ["https://sqs.us-east-1.amazonaws.com/166060576821/cloudtrail-east"]
          s3_bucket_patterns = ["east*"]
          kms_key_arns       = []
        },
      ]
    }
  }

  assert {
    condition = toset(keys(output.splunk_cloud_input_s3_logs_json)) == toset([
      "forge-cloudtrail-east",
      "forge-cloudtrail-west",
    ])
    error_message = "Reordering list items must preserve the name-keyed Terraform identities."
  }
}

run "s3_logs_disabled_items_contract" {
  command = plan

  variables {
    s3_logs_config = {
      "s3-custom-logs" = [
        {
          enabled            = false
          name               = ""
          iam_region         = ""
          index              = ""
          sqs_urls           = []
          s3_bucket_patterns = []
          kms_key_arns       = []
        },
      ]
    }
  }

  assert {
    condition = (
      length(output.splunk_cloud_input_s3_logs_json) == 0
      && length(aws_cloudformation_stack.cf_splunk_s3_logs_iam_region) == 0
    )
    error_message = "Disabled S3 list items must create no Data Manager input or stack."
  }
}

run "s3_logs_empty_config_contract" {
  command = plan

  variables {
    s3_logs_config = {}
  }

  assert {
    condition = (
      output.splunk_cloud_input_s3_logs_json == tomap({})
      && length(aws_cloudformation_stack.cf_splunk_s3_logs_iam_region) == 0
    )
    error_message = "The default empty S3 configuration must return an empty map and create no stacks."
  }
}

run "s3_logs_empty_kms_contract" {
  command = plan

  variables {
    s3_logs_config = {
      "s3-access-logs" = [
        {
          enabled            = true
          name               = "forge-s3-access"
          iam_region         = "us-east-1"
          index              = "forge-index"
          sqs_urls           = ["https://sqs.us-east-1.amazonaws.com/166060576821/s3-access-events"]
          s3_bucket_patterns = ["s3access*"]
          kms_key_arns       = []
        },
      ]
    }
  }

  assert {
    condition     = jsondecode(output.splunk_cloud_input_s3_logs_json["forge-s3-access"]).details.kmsKeyArns == []
    error_message = "Every S3 input must allow and serialize an empty KMS key ARN list."
  }
}

run "s3_logs_rejects_foreign_queue_account" {
  command = plan

  variables {
    s3_logs_config = {
      "ct-logs" = [
        {
          enabled            = true
          name               = "foreign-input"
          iam_region         = "us-east-1"
          index              = "forge-index"
          sqs_urls           = ["https://sqs.us-east-1.amazonaws.com/999999999999/foreign-events"]
          s3_bucket_patterns = ["test*"]
          kms_key_arns       = []
        },
      ]
    }
  }

  expect_failures = [
    aws_cloudformation_stack.cf_splunk_s3_logs_iam_region["foreign-input"],
  ]
}

run "s3_logs_rejects_invalid_required_fields" {
  command = plan

  variables {
    s3_logs_config = {
      "ct-logs" = [
        {
          enabled            = true
          name               = "forge-cloudtrail"
          iam_region         = ""
          index              = "forge-index"
          sqs_urls           = []
          s3_bucket_patterns = []
          kms_key_arns       = []
        },
      ]
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
      "cf-access-logs" = [
        {
          enabled            = true
          name               = "forge-cloudfront"
          iam_region         = "us-east-1"
          index              = "forge-index"
          sqs_urls           = ["https://example.com/not-an-sqs-queue"]
          s3_bucket_patterns = ["test*"]
          kms_key_arns       = []
        },
      ]
    }
  }

  expect_failures = [
    var.s3_logs_config,
  ]
}

run "s3_logs_requires_custom_source_type" {
  command = plan

  variables {
    s3_logs_config = {
      "s3-custom-logs" = [
        {
          enabled            = true
          name               = "forge-custom"
          iam_region         = "us-east-1"
          index              = "forge-index"
          sqs_urls           = ["https://sqs.us-east-1.amazonaws.com/166060576821/custom-events"]
          s3_bucket_patterns = ["test*"]
          kms_key_arns       = []
        },
      ]
    }
  }

  expect_failures = [
    var.s3_logs_config,
  ]
}

run "s3_logs_rejects_duplicate_enabled_names" {
  command = plan

  variables {
    s3_logs_config = {
      "ct-logs" = [
        {
          enabled            = true
          name               = "duplicate-name"
          iam_region         = "us-east-1"
          index              = "forge-index"
          sqs_urls           = ["https://sqs.us-east-1.amazonaws.com/166060576821/cloudtrail-events"]
          s3_bucket_patterns = ["test*"]
          kms_key_arns       = []
        },
      ]
      "s3-access-logs" = [
        {
          enabled            = true
          name               = "duplicate-name"
          iam_region         = "us-east-1"
          index              = "forge-index"
          sqs_urls           = ["https://sqs.us-east-1.amazonaws.com/166060576821/s3-access-events"]
          s3_bucket_patterns = ["test*"]
          kms_key_arns       = []
        },
      ]
    }
  }

  expect_failures = [
    var.s3_logs_config,
  ]
}

run "s3_logs_rejects_shared_queues" {
  command = plan

  variables {
    s3_logs_config = {
      "ct-logs" = [
        {
          enabled            = true
          name               = "forge-cloudtrail"
          iam_region         = "us-east-1"
          index              = "forge-index"
          sqs_urls           = ["https://sqs.us-east-1.amazonaws.com/166060576821/shared-events"]
          s3_bucket_patterns = ["cloudtrail*"]
          kms_key_arns       = []
        },
      ]
      "s3-access-logs" = [
        {
          enabled            = true
          name               = "forge-s3-access"
          iam_region         = "us-east-1"
          index              = "forge-index"
          sqs_urls           = ["https://sqs.us-east-1.amazonaws.com/166060576821/shared-events"]
          s3_bucket_patterns = ["s3access*"]
          kms_key_arns       = []
        },
      ]
    }
  }

  expect_failures = [
    var.s3_logs_config,
  ]
}
