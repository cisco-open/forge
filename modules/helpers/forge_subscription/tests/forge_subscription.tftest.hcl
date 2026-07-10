mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Action\":[\"sts:AssumeRole\",\"s3:GetObject\",\"secretsmanager:GetSecretValue\",\"ec2:CreateImage\",\"ecr:GetAuthorizationToken\"],\"Effect\":\"Allow\",\"Resource\":\"*\"}]}"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      id  = "role_for_forge_runners"
      arn = "arn:aws:iam::123456789012:role/role_for_forge_runners"
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
      "arn:aws:iam::210987654321:role/forge-runner"
    ]
    ecr_repositories = {
      names                  = []
      ecr_access_account_ids = []
      regions                = []
    }
  }
}

run "forge_subscription_runner_role_contract" {
  command = plan

  assert {
    condition = (
      aws_iam_role.role_for_forge_runners.name == "role_for_forge_runners"
      && aws_iam_role.role_for_forge_runners.max_session_duration == 21600
      && strcontains(aws_iam_role.role_for_forge_runners.assume_role_policy, "sts:AssumeRole")
      && aws_iam_role.role_for_forge_runners.tags.Product == "Forge"
      && aws_iam_role.role_for_forge_runners.tags.Env == "test"
    )
    error_message = "Forge subscription must keep the dedicated tenant role, six-hour sessions, assume role trust, and merged tags."
  }

  assert {
    condition = (
      aws_iam_role_policy.s3_access_for_forge_runners.name == "allow_scoped_s3_access_for_forge_runners"
      && aws_iam_role_policy.s3_access_for_forge_runners.role == aws_iam_role.role_for_forge_runners.id
      && strcontains(aws_iam_role_policy.s3_access_for_forge_runners.policy, "s3:GetObject")
      && aws_iam_role_policy.secrets_access_for_forge_runners.name == "allow_scoped_secrets_access_for_forge_runners"
      && strcontains(aws_iam_role_policy.secrets_access_for_forge_runners.policy, "secretsmanager:GetSecretValue")
      && aws_iam_role_policy.packer_support_for_forge_runners.name == "allow_scoped_packer_support_for_forge_runners"
      && strcontains(aws_iam_role_policy.packer_support_for_forge_runners.policy, "ec2:CreateImage")
      && strcontains(aws_iam_role_policy.packer_support_for_forge_runners.policy, "ecr:GetAuthorizationToken")
      && length(aws_ecr_repository_policy.repository_policy) == 0
    )
    error_message = "Forge subscription must keep S3, Secrets Manager, and Packer inline policies, while skipping regional ECR policies when no repositories are configured."
  }
}
