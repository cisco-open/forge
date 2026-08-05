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

  mock_resource "aws_servicecatalogappregistry_application" {
    defaults = {
      application_tag = {
        awsApplication = "arn:aws:resource-groups:us-east-1:123456789012:group/splunk-o11y"
      }
    }
  }

  mock_resource "aws_cloudformation_stack" {
    defaults = {
      id = "arn:aws:cloudformation:us-east-1:123456789012:stack/splunk-integration/mock-stack-id"
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

  assert {
    condition = (
      terraform_data.cloudwatch_metric_stream_tags.input.aws_profile == "test"
      && terraform_data.cloudwatch_metric_stream_tags.input.region == "us-east-1"
      && terraform_data.cloudwatch_metric_stream_tags.input.stack_id == "arn:aws:cloudformation:us-east-1:123456789012:stack/splunk-integration/mock-stack-id"
      && terraform_data.cloudwatch_metric_stream_tags.input.stream_name_prefix == "splunk-metric-stream-"
      && terraform_data.cloudwatch_metric_stream_tags.input.tags.Product == "Forge"
      && terraform_data.cloudwatch_metric_stream_tags.input.tags.Env == "test"
      && terraform_data.cloudwatch_metric_stream_tags.input.tags.awsApplication == "arn:aws:resource-groups:us-east-1:123456789012:group/splunk-o11y"
    )
    error_message = "Metric Stream tag management must retain the stack identity, configured profile and region, discovery prefix, and merged Forge tags."
  }

  assert {
    condition = (
      length(terraform_data.cloudwatch_metric_stream_tags.triggers_replace) == 4
      && terraform_data.cloudwatch_metric_stream_tags.triggers_replace[0] == terraform_data.cloudwatch_metric_stream_tags.input.stack_id
      && terraform_data.cloudwatch_metric_stream_tags.triggers_replace[1] == "https://example.com/splunk-integration.yaml"
      && terraform_data.cloudwatch_metric_stream_tags.triggers_replace[2] == filesha256("${path.module}/scripts/manage_cloudwatch_metric_stream_tags.sh")
      && terraform_data.cloudwatch_metric_stream_tags.triggers_replace[3] == sha256(jsonencode(terraform_data.cloudwatch_metric_stream_tags.input.tags))
    )
    error_message = "Metric Stream tag management must replace on stack, template, script, or desired-tag changes."
  }
}
