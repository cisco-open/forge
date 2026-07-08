mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_resource "aws_cloudwatch_event_bus" {
    defaults = {
      arn = "arn:aws:events:us-east-1:210987654321:event-bus/forge-destination"
    }
  }

  mock_resource "aws_cloudwatch_event_rule" {
    defaults = {
      arn = "arn:aws:events:us-east-1:210987654321:rule/forge-destination/forge-webhook-receive-0"
    }
  }
}

variables {
  aws_profile = "test"
  aws_region  = "us-east-1"
  default_tags = {
    Product = "Forge"
  }
  tags = {
    Env = "test"
  }
  reader_config = {
    role_name              = "github-webhook-relay-secret-reader"
    role_trust_principals  = ["arn:aws:iam::123456789012:role/source-reader"]
    source_secret_role_arn = ""
    enable_secret_fetch    = false
    source_secret_arn      = ""
    source_secret_region   = ""
  }
  webhook_relay_destination_config = {
    name_prefix                = "forge-webhook"
    destination_event_bus_name = "forge-destination"
    source_account_id          = "123456789012"
    targets = [
      {
        event_pattern       = jsonencode({ source = ["forge.webhook"], detail-type = ["workflow_job"] })
        lambda_function_arn = "arn:aws:lambda:us-east-1:210987654321:function:receiver"
      },
    ]
  }
}

run "webhook_destination_bus_contract" {
  assert {
    condition = (
      aws_cloudwatch_event_bus.destination.name == "forge-destination"
      && aws_cloudwatch_event_bus.destination.log_config[0].include_detail == "NONE"
      && aws_cloudwatch_event_bus.destination.log_config[0].level == "OFF"
    )
    error_message = "Webhook relay destination bus must keep operator-chosen logging defaults."
  }

  assert {
    condition = (
      jsondecode(aws_cloudwatch_event_bus_policy.allow_source.policy).Statement[0].Principal.AWS == "123456789012"
      && jsondecode(aws_cloudwatch_event_bus_policy.allow_source.policy).Statement[0].Action == "events:PutEvents"
      && jsondecode(aws_cloudwatch_event_bus_policy.allow_source.policy).Statement[0].Resource == aws_cloudwatch_event_bus.destination.arn
    )
    error_message = "Webhook relay destination bus policy must only allow PutEvents from the configured source account."
  }
}

run "webhook_destination_target_contract" {
  assert {
    condition = (
      aws_cloudwatch_event_rule.receive["0"].name == "forge-webhook-receive-0"
      && jsondecode(aws_cloudwatch_event_rule.receive["0"].event_pattern).source[0] == "forge.webhook"
      && aws_cloudwatch_event_target.lambda["0"].arn == "arn:aws:lambda:us-east-1:210987654321:function:receiver"
    )
    error_message = "Webhook relay destination must preserve indexed receive rules and Lambda targets."
  }

  assert {
    condition = (
      aws_lambda_permission.eventbridge_invoke["0"].principal == "events.amazonaws.com"
      && aws_lambda_permission.eventbridge_invoke["0"].function_name == "arn:aws:lambda:us-east-1:210987654321:function:receiver"
      && aws_lambda_permission.eventbridge_invoke["0"].source_arn == aws_cloudwatch_event_rule.receive["0"].arn
    )
    error_message = "Webhook relay destination Lambda permission must stay scoped to the receive rule."
  }
}

run "webhook_destination_reader_contract" {
  assert {
    condition = (
      aws_iam_role.reader.name == "github-webhook-relay-secret-reader"
      && length(aws_iam_role_policy.allow_assume_external_inline) == 0
    )
    error_message = "Webhook relay reader role must preserve trust principals and keep external secret fetch disabled by default."
  }
}
