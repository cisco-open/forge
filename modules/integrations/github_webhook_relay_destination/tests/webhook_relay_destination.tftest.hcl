mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":\"sts:AssumeRole\",\"Resource\":\"arn:aws:iam::210987654321:role/source-secret-reader\",\"Principal\":{\"AWS\":\"arn:aws:iam::123456789012:root\"}}]}"
    }
  }

  mock_resource "aws_cloudwatch_event_bus" {
    defaults = {
      arn = "arn:aws:events:us-east-1:123456789012:event-bus/forge-webhook-destination"
    }
  }

  mock_resource "aws_cloudwatch_event_rule" {
    defaults = {
      arn = "arn:aws:events:us-east-1:123456789012:rule/forge-webhook-destination/forge-webhook-receive-0"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      id  = "github-webhook-relay-secret-reader"
      arn = "arn:aws:iam::123456789012:role/github-webhook-relay-secret-reader"
    }
  }
}

mock_provider "external" {
  mock_data "external" {
    defaults = {
      result = {
        secret_value = "webhook-secret-value"
      }
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
    role_name = "github-webhook-relay-secret-reader"
    role_trust_principals = [
      "arn:aws:iam::123456789012:root"
    ]
    enable_secret_fetch    = false
    source_secret_role_arn = "arn:aws:iam::210987654321:role/source-secret-reader"
    source_secret_arn      = "arn:aws:secretsmanager:us-east-1:210987654321:secret:forge/webhook"
    source_secret_region   = "us-east-1"
  }
  webhook_relay_destination_config = {
    name_prefix                = "forge-webhook"
    destination_event_bus_name = "forge-webhook-destination"
    source_account_id          = "210987654321"
    targets = [
      {
        event_pattern       = "{\"detail\":{\"action\":[\"completed\"]}}"
        lambda_function_arn = "arn:aws:lambda:us-east-1:123456789012:function:webex-relay"
      },
      {
        event_pattern       = "{\"detail\":{\"action\":[\"queued\"]}}"
        lambda_function_arn = "arn:aws:lambda:us-east-1:123456789012:function:queue-relay"
      },
    ]
  }
}

run "webhook_relay_destination_contract" {
  command = plan

  assert {
    condition = (
      aws_cloudwatch_event_bus.destination.name == "forge-webhook-destination"
      && aws_cloudwatch_event_bus.destination.log_config[0].include_detail == "NONE"
      && aws_cloudwatch_event_bus.destination.log_config[0].level == "OFF"
      && aws_cloudwatch_event_bus.destination.tags.Product == "Forge"
      && aws_cloudwatch_event_bus.destination.tags.Env == "test"
    )
    error_message = "Webhook relay destination must create the configured EventBridge bus with logging disabled and merged tags."
  }

  assert {
    condition = (
      strcontains(aws_cloudwatch_event_bus_policy.allow_source.policy, "210987654321")
      && strcontains(aws_cloudwatch_event_bus_policy.allow_source.policy, "events:PutEvents")
      && strcontains(aws_cloudwatch_event_bus_policy.allow_source.policy, "forge-webhook-destination")
      && aws_cloudwatch_event_rule.receive["0"].name == "forge-webhook-receive-0"
      && aws_cloudwatch_event_rule.receive["0"].event_pattern == "{\"detail\":{\"action\":[\"completed\"]}}"
      && aws_cloudwatch_event_rule.receive["1"].name == "forge-webhook-receive-1"
      && aws_cloudwatch_event_target.lambda["0"].arn == "arn:aws:lambda:us-east-1:123456789012:function:webex-relay"
      && aws_cloudwatch_event_target.lambda["1"].arn == "arn:aws:lambda:us-east-1:123456789012:function:queue-relay"
      && aws_lambda_permission.eventbridge_invoke["0"].principal == "events.amazonaws.com"
    )
    error_message = "Webhook relay destination must fan out target rules, targets, permissions, and source-account bus policy from inputs."
  }

  assert {
    condition = (
      aws_iam_role.reader.name == "github-webhook-relay-secret-reader"
      && strcontains(aws_iam_role.reader.assume_role_policy, "arn:aws:iam::123456789012:root")
      && length(aws_iam_role_policy.allow_assume_external_inline) == 0
      && output.role_arn == "arn:aws:iam::123456789012:role/github-webhook-relay-secret-reader"
      && output.webhook == null
    )
    error_message = "Webhook relay destination must expose the reader role and skip external secret fetch policy/output when disabled."
  }
}

run "webhook_relay_destination_secret_fetch_contract" {
  command = apply

  variables {
    reader_config = {
      role_name = "github-webhook-relay-secret-reader"
      role_trust_principals = [
        "arn:aws:iam::123456789012:root"
      ]
      enable_secret_fetch    = true
      source_secret_role_arn = "arn:aws:iam::210987654321:role/source-secret-reader"
      source_secret_arn      = "arn:aws:secretsmanager:us-east-1:210987654321:secret:forge/webhook"
      source_secret_region   = "us-east-1"
    }
  }

  assert {
    condition = (
      length(aws_iam_role_policy.allow_assume_external_inline) == 1
      && aws_iam_role_policy.allow_assume_external_inline[0].name == "github-webhook-relay-secret-reader-assume-external"
      && strcontains(aws_iam_role_policy.allow_assume_external_inline[0].policy, "arn:aws:iam::210987654321:role/source-secret-reader")
      && data.external.fetch_secret_value[0].result.secret_value == "webhook-secret-value"
    )
    error_message = "Webhook relay destination must attach external assume-role policy and expose fetched webhook secret when secret fetch is enabled."
  }
}

run "webhook_relay_destination_wiring_contract" {
  command = plan

  assert {
    condition = (
      jsondecode(aws_cloudwatch_event_bus_policy.allow_source.policy).Statement[0].Principal.AWS == "210987654321"
      && jsondecode(aws_cloudwatch_event_bus_policy.allow_source.policy).Statement[0].Action == "events:PutEvents"
      && jsondecode(aws_cloudwatch_event_bus_policy.allow_source.policy).Statement[0].Resource == aws_cloudwatch_event_bus.destination.arn
    )
    error_message = "Webhook relay destination bus policy must only allow PutEvents from the configured source account."
  }

  assert {
    condition = (
      aws_lambda_permission.eventbridge_invoke["0"].principal == "events.amazonaws.com"
      && aws_lambda_permission.eventbridge_invoke["0"].function_name == "arn:aws:lambda:us-east-1:123456789012:function:webex-relay"
      && aws_lambda_permission.eventbridge_invoke["0"].source_arn == aws_cloudwatch_event_rule.receive["0"].arn
    )
    error_message = "Webhook relay destination Lambda permission must stay scoped to the receive rule."
  }
}
