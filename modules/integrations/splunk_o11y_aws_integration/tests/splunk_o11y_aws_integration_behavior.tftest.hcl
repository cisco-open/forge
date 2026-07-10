mock_provider "aws" {
  mock_data "aws_secretsmanager_secret" {
    defaults = {
      id  = "/cicd/common/splunk_o11y_ingest_token_aws_integration"
      arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:splunk-token"
    }
  }

  mock_data "aws_secretsmanager_secret_version" {
    defaults = {
      secret_string = "mock-splunk-access-token"
    }
  }
}

variables {
  aws_profile       = "test"
  aws_region        = "us-east-1"
  splunk_ingest_url = "https://ingest.us1.signalfx.com"
  template_url      = "https://example.com/splunk-integration.yaml"
  default_tags = {
    Product = "Forge"
  }
  tags = {
    Env = "test"
  }
}

run "splunk_o11y_cloudformation_stack_contract" {
  command = plan

  assert {
    condition = (
      aws_cloudformation_stack.splunk_integration.name == "splunk-integration"
      && aws_cloudformation_stack.splunk_integration.template_url == "https://example.com/splunk-integration.yaml"
      && aws_cloudformation_stack.splunk_integration.parameters.SplunkAccessToken == "mock-splunk-access-token"
      && aws_cloudformation_stack.splunk_integration.parameters.SplunkIngestUrl == "https://ingest.us1.signalfx.com"
    )
    error_message = "Splunk o11y AWS integration must pass the Splunk token, ingest URL, and operator template URL into CloudFormation."
  }

  assert {
    condition = (
      contains(aws_cloudformation_stack.splunk_integration.capabilities, "CAPABILITY_AUTO_EXPAND")
      && contains(aws_cloudformation_stack.splunk_integration.capabilities, "CAPABILITY_NAMED_IAM")
      && aws_cloudformation_stack.splunk_integration.tags.Product == "Forge"
      && aws_cloudformation_stack.splunk_integration.tags.Env == "test"
    )
    error_message = "Splunk o11y AWS integration stack must keep IAM capabilities and merged Forge tags."
  }
}
