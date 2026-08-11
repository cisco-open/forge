mock_provider "aws" {
  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::166060576821:role/mock-lambda-role"
    }
  }

  mock_resource "aws_lambda_function" {
    defaults = {
      arn = "arn:aws:lambda:eu-west-1:166060576821:function:mock-reconciler"
    }
  }

  mock_resource "aws_cloudwatch_event_rule" {
    defaults = {
      arn = "arn:aws:events:eu-west-1:166060576821:rule/mock-reconciler-sweep"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "166060576821"
      arn        = "arn:aws:iam::166060576821:user/test"
      user_id    = "test"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
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
        build_plan          = "{}"
        build_plan_filename = "/tmp/mock-lambda-build-plan"
        filename            = "/tmp/mock-lambda.zip"
        template_hash       = "template-sha"
        timestamp           = "0"
        version             = "1"
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
  default_tags = {
    Product = "Forge"
  }
  tags = {
    Env = "test"
  }
}

run "disabled_inputs_create_no_log_group_reconciler" {
  command = plan

  assert {
    condition = (
      length(aws_lambda_invocation.splunk_dm_log_group_reconciler) == 0
    )
    error_message = "No regional reconciler invocation should exist when every Data Manager input is disabled."
  }
}

run "s3_all_datasets_request_and_stack_contract" {
  command = plan

  variables {
    s3_logs_config = {
      "s3-custom-logs" = [
        {
          enabled     = true
          name        = "forge-custom"
          iam_region  = "us-east-1"
          index       = "forge-custom-index"
          source_type = "forgecicd:custom:s3"
          sqs_urls = [
            "https://sqs.us-east-1.amazonaws.com/166060576821/custom-events",
            "https://sqs.us-west-2.amazonaws.com/166060576821/custom-audit-events",
          ]
          s3_bucket_patterns = ["custom*", "archive*"]
          kms_key_arns = [
            "arn:aws:kms:us-east-1:166060576821:key/11111111-1111-1111-1111-111111111111",
          ]
        },
      ]
      "ct-logs" = [
        {
          enabled            = true
          name               = "forge-cloudtrail"
          iam_region         = "us-east-1"
          index              = "forge-cloudtrail-index"
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
          index              = "forge-s3-access-index"
          sqs_urls           = ["https://sqs.eu-west-1.amazonaws.com/166060576821/s3-access-events"]
          s3_bucket_patterns = ["s3access*"]
          kms_key_arns       = []
        },
      ]
      "elb-access-logs" = [
        {
          enabled            = true
          name               = "forge-elb-access"
          iam_region         = "us-west-2"
          index              = "forge-elb-access-index"
          sqs_urls           = ["https://sqs.us-west-2.amazonaws.com/166060576821/elb-access-events"]
          s3_bucket_patterns = ["elbaccess*"]
          kms_key_arns       = []
        },
      ]
      "cf-access-logs" = [
        {
          enabled            = true
          name               = "forge-cloudfront-access"
          iam_region         = "us-east-2"
          index              = "forge-cloudfront-access-index"
          sqs_urls           = ["https://sqs.us-east-2.amazonaws.com/166060576821/cloudfront-access-events"]
          s3_bucket_patterns = ["cloudfront*"]
          kms_key_arns       = []
        },
      ]
    }
  }

  assert {
    condition = toset(keys(output.splunk_cloud_input_s3_logs_json)) == toset([
      "forge-custom",
      "forge-cloudtrail",
      "forge-s3-access",
      "forge-elb-access",
      "forge-cloudfront-access",
    ])
    error_message = "Every supported S3 dataset must generate one independently keyed Data Manager input."
  }

  assert {
    condition = alltrue([
      for item in [
        { name = "forge-custom", dataset = "s3-custom-logs", index = "forge-custom-index" },
        { name = "forge-cloudtrail", dataset = "ct-logs", index = "forge-cloudtrail-index" },
        { name = "forge-s3-access", dataset = "s3-access-logs", index = "forge-s3-access-index" },
        { name = "forge-elb-access", dataset = "elb-access-logs", index = "forge-elb-access-index" },
        { name = "forge-cloudfront-access", dataset = "cf-access-logs", index = "forge-cloudfront-access-index" },
        ] : (
        keys(jsondecode(output.splunk_cloud_input_s3_logs_json[item.name]).destination.details) == [item.dataset]
        && jsondecode(output.splunk_cloud_input_s3_logs_json[item.name]).destination.details[item.dataset] == item.index
        && keys(jsondecode(output.splunk_cloud_input_s3_logs_json[item.name]).details.datasetInfo) == [item.dataset]
      )
    ])
    error_message = "Every input must use its selected dataset key for both the destination and datasetInfo payloads."
  }

  assert {
    condition = (
      jsondecode(output.splunk_cloud_input_s3_logs_json["forge-custom"]).name == "forge-custom"
      && jsondecode(output.splunk_cloud_input_s3_logs_json["forge-custom"]).type == "AWS"
      && jsondecode(output.splunk_cloud_input_s3_logs_json["forge-custom"]).mode == "Complete"
      && jsondecode(output.splunk_cloud_input_s3_logs_json["forge-custom"]).destination.type == "index"
      && jsondecode(output.splunk_cloud_input_s3_logs_json["forge-custom"]).details.type == "SingleAccount"
      && jsondecode(output.splunk_cloud_input_s3_logs_json["forge-custom"]).details.iamRegion == "us-east-1"
      && jsondecode(output.splunk_cloud_input_s3_logs_json["forge-custom"]).details.dataAccounts == ["166060576821"]
      && jsondecode(output.splunk_cloud_input_s3_logs_json["forge-custom"]).details.datasetInfo["s3-custom-logs"] == {
        sourceType = "forgecicd:custom:s3"
        sqsUrls = [
          { sqsUrl = "https://sqs.us-east-1.amazonaws.com/166060576821/custom-events" },
          { sqsUrl = "https://sqs.us-west-2.amazonaws.com/166060576821/custom-audit-events" },
        ]
      }
      && jsondecode(output.splunk_cloud_input_s3_logs_json["forge-custom"]).details.s3BucketPatterns == ["custom*", "archive*"]
      && jsondecode(output.splunk_cloud_input_s3_logs_json["forge-custom"]).details.kmsKeyArns == [
        "arn:aws:kms:us-east-1:166060576821:key/11111111-1111-1111-1111-111111111111",
      ]
      && !contains(keys(jsondecode(output.splunk_cloud_input_s3_logs_json["forge-custom"]).details), "regions")
      && !contains(keys(jsondecode(output.splunk_cloud_input_s3_logs_json["forge-custom"]).details), "resourceTags")
    )
    error_message = "The custom S3 payload must preserve its complete request contract, queues, bucket patterns, KMS keys, and source type."
  }

  assert {
    condition = alltrue([
      for item in [
        { name = "forge-cloudtrail", dataset = "ct-logs" },
        { name = "forge-s3-access", dataset = "s3-access-logs" },
        { name = "forge-elb-access", dataset = "elb-access-logs" },
        { name = "forge-cloudfront-access", dataset = "cf-access-logs" },
        ] : !contains(
        keys(jsondecode(output.splunk_cloud_input_s3_logs_json[item.name]).details.datasetInfo[item.dataset]),
        "sourceType",
      )
    ])
    error_message = "Predefined S3 datasets must omit the custom sourceType field."
  }

  assert {
    condition = (
      toset(keys(aws_cloudformation_stack.cf_splunk_s3_logs_iam_region)) == toset([
        "forge-custom",
        "forge-cloudtrail",
        "forge-s3-access",
        "forge-elb-access",
        "forge-cloudfront-access",
      ])
      && alltrue([
        for item in [
          { name = "forge-custom", region = "us-east-1" },
          { name = "forge-cloudtrail", region = "us-east-1" },
          { name = "forge-s3-access", region = "eu-west-1" },
          { name = "forge-elb-access", region = "us-west-2" },
          { name = "forge-cloudfront-access", region = "us-east-2" },
          ] : (
          aws_cloudformation_stack.cf_splunk_s3_logs_iam_region[item.name].region == item.region
          && aws_cloudformation_stack.cf_splunk_s3_logs_iam_region[item.name].name == "SplunkDMSqsS3-00000000-0000-0000-0000-000000000001"
          && aws_cloudformation_stack.cf_splunk_s3_logs_iam_region[item.name].capabilities == toset(["CAPABILITY_NAMED_IAM"])
        )
      ])
    )
    error_message = "Every generated S3 input must create a named-IAM CloudFormation stack in its configured region."
  }

  assert {
    condition = (
      toset(keys(aws_lambda_invocation.splunk_dm_log_group_reconciler)) == toset([
        "eu-west-1",
        "us-east-1",
        "us-east-2",
        "us-west-2",
      ])
      && alltrue([
        for invocation in values(aws_lambda_invocation.splunk_dm_log_group_reconciler) :
        invocation.lifecycle_scope == "CREATE_ONLY"
      ])
    )
    error_message = "S3-only IAM regions must each receive one create/update reconciler invocation."
  }
}

run "s3_dataset_list_filters_disabled_inputs" {
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
          kms_key_arns       = ["arn:aws:kms:us-west-2:166060576821:key/22222222-2222-2222-2222-222222222222"]
        },
        {
          enabled            = false
          name               = "disabled-cloudtrail"
          iam_region         = ""
          index              = ""
          sqs_urls           = []
          s3_bucket_patterns = []
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
    condition = (
      toset(keys(output.splunk_cloud_input_s3_logs_json)) == toset([
        "forge-cloudtrail-east",
        "forge-cloudtrail-west",
      ])
      && toset(keys(aws_cloudformation_stack.cf_splunk_s3_logs_iam_region)) == toset([
        "forge-cloudtrail-east",
        "forge-cloudtrail-west",
      ])
      && jsondecode(output.splunk_cloud_input_s3_logs_json["forge-cloudtrail-east"]).destination.details["ct-logs"] == "forge-east-index"
      && jsondecode(output.splunk_cloud_input_s3_logs_json["forge-cloudtrail-west"]).destination.details["ct-logs"] == "forge-west-index"
      && jsondecode(output.splunk_cloud_input_s3_logs_json["forge-cloudtrail-east"]).details.kmsKeyArns == []
      && !contains(keys(output.splunk_cloud_input_s3_logs_json), "disabled-cloudtrail")
    )
    error_message = "A dataset list must create independent name-keyed inputs, omit disabled entries, and allow an empty KMS list."
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

run "s3_logs_rejects_invalid_enabled_input" {
  command = plan

  variables {
    s3_logs_config = {
      "ct-logs" = [
        {
          enabled            = true
          name               = ""
          iam_region         = ""
          index              = ""
          sqs_urls           = ["https://example.com/not-an-sqs-queue"]
          s3_bucket_patterns = []
          kms_key_arns       = [""]
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
          source_type        = ""
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
