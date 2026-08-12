mock_provider "aws" {
  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::166060576821:role/mock-reconciler"
    }
  }

  mock_resource "aws_lambda_function" {
    defaults = {
      arn = "arn:aws:lambda:eu-west-1:166060576821:function:mock-reconciler"
    }
  }

  mock_resource "aws_cloudwatch_event_rule" {
    defaults = {
      arn = "arn:aws:events:eu-west-1:166060576821:rule/mock-reconciler-delete"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "166060576821"
      arn        = "arn:aws:iam::166060576821:user/test"
      user_id    = "test"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
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

mock_provider "local" {}
mock_provider "null" {}

variables {
  name   = "s3-logs"
  region = "eu-west-1"
  tags = {
    Product = "Forge"
  }
}

run "scopes_reconciler_resources_by_configuration" {
  command = plan

  assert {
    condition = (
      local.function_name == "ForgeSplunkDMLog-s3-logs-eu-west-1"
      && output.lambda_function_name == local.function_name
      && length(local.function_name) <= 64
    )
    error_message = "The reconciler Lambda name must include the configuration name and region within the AWS limit."
  }

  assert {
    condition = (
      local.event_rule_name == "ForgeSplunkDMDel-s3-logs-eu-west-1"
      && aws_cloudwatch_event_rule.lambda_delete.name == local.event_rule_name
      && length(local.event_rule_name) <= 64
      && aws_cloudwatch_event_target.lambda_delete.rule == local.event_rule_name
      && aws_cloudwatch_event_target.lambda_delete.arn == module.log_group_reconciler.lambda_function_arn
    )
    error_message = "The delete rule and target must use the scoped reconciler names and Lambda ARN."
  }

  assert {
    condition = (
      aws_lambda_permission.lambda_delete.function_name == output.lambda_function_name
      && aws_lambda_permission.lambda_delete.source_arn == aws_cloudwatch_event_rule.lambda_delete.arn
      && aws_lambda_permission.lambda_delete.principal == "events.amazonaws.com"
    )
    error_message = "The EventBridge permission must authorize the scoped reconciler Lambda from its delete rule."
  }
}

run "keeps_maximal_alias_names_unique_and_within_aws_limits" {
  command = plan

  variables {
    name   = "custom-cwl-cwl-s3-logs-secmeta"
    region = "ap-southeast-2"
  }

  assert {
    condition = (
      output.lambda_function_name == local.function_name
      && length(local.function_name) == 62
      && length(local.function_name) <= 64
      && local.function_name == "ForgeSplunkDMLog-custom-cwl-cwl-s3-logs-secmeta-ap-southeast-2"
      && local.function_name != "ForgeSplunkDMLog-s3-logs-eu-west-1"
    )
    error_message = "A maximal alias set must produce a distinct collision-safe Lambda name within the 64-character limit."
  }

  assert {
    condition = (
      aws_cloudwatch_event_rule.lambda_delete.name == local.event_rule_name
      && length(local.event_rule_name) == 62
      && length(local.event_rule_name) <= 64
      && local.event_rule_name == "ForgeSplunkDMDel-custom-cwl-cwl-s3-logs-secmeta-ap-southeast-2"
      && local.event_rule_name != "ForgeSplunkDMDel-s3-logs-eu-west-1"
      && aws_cloudwatch_event_target.lambda_delete.rule == local.event_rule_name
      && aws_lambda_permission.lambda_delete.function_name == output.lambda_function_name
      && aws_lambda_permission.lambda_delete.source_arn == aws_cloudwatch_event_rule.lambda_delete.arn
    )
    error_message = "A maximal alias set must keep the EventBridge rule unique, bounded, and wired to the scoped Lambda."
  }
}
