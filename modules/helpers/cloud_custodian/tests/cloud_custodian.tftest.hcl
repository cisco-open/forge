mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Action\":[\"ec2:DeleteSnapshot\",\"ecr:DescribeRepositories\",\"sts:AssumeRole\"],\"Effect\":\"Allow\",\"Resource\":\"*\"}]}"
    }
  }

  mock_resource "aws_iam_policy" {
    defaults = {
      arn = "arn:aws:iam::123456789012:policy/CloudCustodianPolicy"
    }
  }
}

variables {
  aws_profile    = "test"
  aws_region     = "us-east-1"
  forge_role_arn = "arn:aws:iam::123456789012:role/forge-runner"
  default_tags = {
    Product = "Forge"
  }
  tags = {
    Env = "test"
  }
}

run "cloud_custodian_role_policy_contract" {
  command = plan

  assert {
    condition = (
      aws_iam_policy.cloud_custodian_policy.name == "CloudCustodianPolicy"
      && aws_iam_policy.cloud_custodian_policy.description == "Cloud Custodian Policy for managing EC2 resources"
      && aws_iam_policy.cloud_custodian_policy.tags.Product == "Forge"
      && aws_iam_policy.cloud_custodian_policy.tags.Env == "test"
      && strcontains(aws_iam_policy.cloud_custodian_policy.policy, "ec2:DeleteSnapshot")
      && strcontains(aws_iam_policy.cloud_custodian_policy.policy, "ecr:DescribeRepositories")
    )
    error_message = "Cloud Custodian helper must keep cleanup permissions and merged policy tags."
  }

  assert {
    condition = (
      aws_iam_role.cloud_custodian.name == "cloud_custodian"
      && aws_iam_role.cloud_custodian.max_session_duration == 21600
      && strcontains(aws_iam_role.cloud_custodian.assume_role_policy, "sts:AssumeRole")
      && aws_iam_role.cloud_custodian.tags.Product == "Forge"
      && aws_iam_role.cloud_custodian.tags.Env == "test"
      && aws_iam_role_policy_attachment.attach_cloud_custodian_policy.role == aws_iam_role.cloud_custodian.name
      && aws_iam_role_policy_attachment.attach_cloud_custodian_policy.policy_arn == aws_iam_policy.cloud_custodian_policy.arn
    )
    error_message = "Cloud Custodian role must keep 6-hour sessions, assume role trust, tags, and policy attachment."
  }
}
