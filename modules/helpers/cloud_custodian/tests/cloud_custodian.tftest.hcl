mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_resource "aws_iam_policy" {
    defaults = {
      arn = "arn:aws:iam::123456789012:policy/CloudCustodianPolicy"
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
  forge_role_arn = "arn:aws:iam::123456789012:role/forge-runner"
}

run "cloud_custodian_role_contract" {
  command = plan

  assert {
    condition = (
      aws_iam_role.cloud_custodian.name == "cloud_custodian"
      && aws_iam_role.cloud_custodian.max_session_duration == 21600
      && aws_iam_role.cloud_custodian.tags.Product == "Forge"
      && aws_iam_role.cloud_custodian.tags.Env == "test"
    )
    error_message = "Cloud Custodian helper must keep a dedicated 6-hour assumable role with merged security tags."
  }

  assert {
    condition = (
      aws_iam_policy.cloud_custodian_policy.name == "CloudCustodianPolicy"
      && aws_iam_policy.cloud_custodian_policy.description == "Cloud Custodian Policy for managing EC2 resources"
      && aws_iam_role_policy_attachment.attach_cloud_custodian_policy.role == aws_iam_role.cloud_custodian.name
      && aws_iam_role_policy_attachment.attach_cloud_custodian_policy.policy_arn == aws_iam_policy.cloud_custodian_policy.arn
    )
    error_message = "Cloud Custodian policy must remain attached to the dedicated role."
  }
}
