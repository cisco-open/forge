mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
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
  forge = {
    runner_roles = [
      "arn:aws:iam::123456789012:role/forge-runner",
    ]
    ecr_repositories = {
      names                  = []
      ecr_access_account_ids = []
      regions                = []
      provider_regions       = []
    }
  }
}

run "runner_subscription_role_contract" {
  command = plan

  assert {
    condition = (
      aws_iam_role.role_for_forge_runners.name == "role_for_forge_runners"
      && aws_iam_role.role_for_forge_runners.max_session_duration == 21600
      && aws_iam_role.role_for_forge_runners.tags.Product == "Forge"
      && aws_iam_role.role_for_forge_runners.tags.Env == "test"
    )
    error_message = "Forge subscription helper must keep the dedicated 6-hour runner role with merged tags."
  }

  assert {
    condition = (
      aws_iam_role_policy.s3_access_for_forge_runners.name == "allow_scoped_s3_access_for_forge_runners"
      && aws_iam_role_policy.secrets_access_for_forge_runners.name == "allow_scoped_secrets_access_for_forge_runners"
      && aws_iam_role_policy.packer_support_for_forge_runners.name == "allow_scoped_packer_support_for_forge_runners"
      && aws_iam_role_policy.s3_access_for_forge_runners.role == aws_iam_role.role_for_forge_runners.id
    )
    error_message = "Forge subscription helper must keep S3, secrets, and Packer inline policies attached to the runner role."
  }
}
