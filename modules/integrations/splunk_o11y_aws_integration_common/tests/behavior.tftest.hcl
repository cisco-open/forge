mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:user/test"
      user_id    = "test"
    }
  }

  mock_data "aws_secretsmanager_secret" {
    defaults = {
      id = "/cicd/common/splunk-o11y"
    }
  }

  mock_data "aws_secretsmanager_secret_version" {
    defaults = {
      secret_string = "mock-splunk-credential"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/splunk-o11y-sp"
      id  = "splunk-o11y-sp"
    }
  }
}

mock_provider "signalfx" {
  mock_resource "signalfx_aws_external_integration" {
    defaults = {
      id                   = "signalfx-external-aws"
      external_id          = "external-123"
      signalfx_aws_account = "arn:aws:iam::999999999999:root"
    }
  }
}

variables {
  aws_profile            = "test"
  aws_region             = "us-east-1"
  integration_name       = "forge-aws-o11y"
  integration_regions    = ["us-east-1", "us-west-2"]
  splunk_api_url         = "https://api.us1.signalfx.com"
  splunk_organization_id = "org-123"
  default_tags = {
    Product = "Forge"
  }
  tags = {
    Env = "test"
  }
}

run "splunk_o11y_aws_role_and_integration_contract" {
  command = plan

  assert {
    condition = (
      aws_iam_role.splunk_integration.name == "splunk-o11y-sp"
      && aws_iam_role.splunk_integration.tags.Product == "Forge"
      && aws_iam_role.splunk_integration.tags.Env == "test"
      && aws_iam_role_policy.splunk_integration.name == "SplunkObservabilityPolicy"
      && aws_iam_role_policy.splunk_managed_policy.name == "SplunkManagedMetricStreams"
    )
    error_message = "Splunk o11y common integration must keep the dedicated IAM role, policy names, and merged tags."
  }

  assert {
    condition = (
      output.iam_role_splunk_integration == aws_iam_role.splunk_integration.arn
      && time_sleep.wait_30_seconds.create_duration == "30s"
    )
    error_message = "Splunk o11y common integration output must expose the IAM role ARN and keep the propagation wait before enabling the vendor integration."
  }
}
