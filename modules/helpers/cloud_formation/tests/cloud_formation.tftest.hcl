mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

override_data {
  target = data.aws_caller_identity.current
  values = {
    account_id = "123456789012"
    arn        = "arn:aws:iam::123456789012:user/test"
    user_id    = "test"
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

run "stackset_role_names_and_policies_are_stable" {
  command = plan

  assert {
    condition = (
      aws_iam_role.cloudformation_admin_role.name == "AWSCloudFormationStackSetAdministrationRole"
      && aws_iam_role.cloudformation_execution_role.name == "AWSCloudFormationStackSetExecutionRole"
      && aws_iam_role.cloudformation_admin_role.tags.Product == "Forge"
      && aws_iam_role.cloudformation_execution_role.tags.Env == "test"
    )
    error_message = "CloudFormation helper must keep the AWS StackSet admin/execution role names and merged tags."
  }

  assert {
    condition = (
      aws_iam_role_policy.admin_assume_execution_role_policy_attachment.name == "AWSCloudFormationStackSetAdministrationRolePolicy"
      && aws_iam_role_policy.admin_assume_execution_role_policy_attachment.role == aws_iam_role.cloudformation_admin_role.id
      && aws_iam_role_policy.execution_role_policy_attachment.name == "AWSCloudFormationStackSetExecutionRolePolicy"
      && aws_iam_role_policy.execution_role_policy_attachment.role == aws_iam_role.cloudformation_execution_role.id
    )
    error_message = "CloudFormation helper must keep the expected inline policies attached to their StackSet roles."
  }
}
