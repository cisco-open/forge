mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:user/test"
      user_id    = "test"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":[\"sts:AssumeRole\",\"cloudformation:*\",\"secretsmanager:*\",\"tag:TagResources\"],\"Resource\":[\"arn:aws:iam::123456789012:role/AWSCloudFormationStackSetAdministrationRole\",\"arn:aws:iam::*:role/AWSCloudFormationStackSetExecutionRole\"],\"Principal\":{\"Service\":\"cloudformation.amazonaws.com\",\"AWS\":\"arn:aws:iam::123456789012:role/AWSCloudFormationStackSetAdministrationRole\"}}]}"
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
}

run "cloudformation_stackset_roles_contract" {
  command = plan

  assert {
    condition = (
      aws_iam_role.cloudformation_admin_role.name == "AWSCloudFormationStackSetAdministrationRole"
      && strcontains(aws_iam_role.cloudformation_admin_role.assume_role_policy, "cloudformation.amazonaws.com")
      && aws_iam_role_policy.admin_assume_execution_role_policy_attachment.name == "AWSCloudFormationStackSetAdministrationRolePolicy"
      && strcontains(aws_iam_role_policy.admin_assume_execution_role_policy_attachment.policy, "AWSCloudFormationStackSetExecutionRole")
      && aws_iam_role.cloudformation_admin_role.tags.Product == "Forge"
      && aws_iam_role.cloudformation_admin_role.tags.Env == "test"
    )
    error_message = "CloudFormation helper must keep the StackSet administration role, assume-role policy, and merged tags."
  }

  assert {
    condition = (
      aws_iam_role.cloudformation_execution_role.name == "AWSCloudFormationStackSetExecutionRole"
      && strcontains(aws_iam_role.cloudformation_execution_role.assume_role_policy, "arn:aws:iam::123456789012:role/AWSCloudFormationStackSetAdministrationRole")
      && aws_iam_role_policy.execution_role_policy_attachment.name == "AWSCloudFormationStackSetExecutionRolePolicy"
      && strcontains(aws_iam_role_policy.execution_role_policy_attachment.policy, "cloudformation:*")
      && strcontains(aws_iam_role_policy.execution_role_policy_attachment.policy, "secretsmanager:*")
      && strcontains(aws_iam_role_policy.execution_role_policy_attachment.policy, "tag:TagResources")
      && aws_iam_role.cloudformation_execution_role.tags.Product == "Forge"
      && aws_iam_role.cloudformation_execution_role.tags.Env == "test"
    )
    error_message = "CloudFormation helper must keep the StackSet execution role, admin trust, broad execution policy, and merged tags."
  }
}
