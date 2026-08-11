mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Action\":[\"sts:AssumeRole\",\"s3:GetObject\",\"secretsmanager:GetSecretValue\",\"ec2:CreateImage\",\"ecr:GetAuthorizationToken\",\"lambda:CreateMicrovmImage\",\"lambda:GetNetworkConnector\",\"lambda:PassNetworkConnector\"],\"Effect\":\"Allow\",\"Resource\":\"*\"}]}"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      id  = "role_for_forge_runners"
      arn = "arn:aws:iam::123456789012:role/role_for_forge_runners"
    }
  }

  mock_resource "aws_iam_policy" {
    defaults = {
      id  = "arn:aws:iam::123456789012:policy/forge-microvm-image-management"
      arn = "arn:aws:iam::123456789012:policy/forge-microvm-image-management"
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
      && aws_iam_policy.microvm_image_management.name == "forge-microvm-image-management"
      && strcontains(aws_iam_policy.microvm_image_management.policy, "lambda:CreateMicrovmImage")
      && strcontains(aws_iam_policy.microvm_image_management.policy, "lambda:GetNetworkConnector")
      && strcontains(aws_iam_policy.microvm_image_management.policy, "lambda:PassNetworkConnector")
      && aws_iam_role_policy_attachment.microvm_image_management.role == aws_iam_role.role_for_forge_runners.name
      && aws_iam_role_policy_attachment.microvm_image_management.policy_arn == aws_iam_policy.microvm_image_management.arn
    )
    error_message = "Forge subscription must keep its existing inline policies and attach one account-wide MicroVM image-management policy to role_for_forge_runners."
  }

  assert {
    condition = (
      length(regexall("(?s)sid\\s*=\\s*\"CreateAndDiscoverMicrovmImages\".*?resources\\s*=\\s*\\[\"\\*\"\\]", file("${path.module}/policies.tf"))) == 1
      && length(regexall("(?s)sid\\s*=\\s*\"ManageMicrovmImages\".*?resources\\s*=\\s*\\[\"\\*\"\\]", file("${path.module}/policies.tf"))) == 1
      && length(regexall("(?s)sid\\s*=\\s*\"ResolveAndPassMicrovmNetworkConnectors\".*?actions\\s*=\\s*\\[.*?\"lambda:GetNetworkConnector\".*?\"lambda:PassNetworkConnector\".*?\\].*?resources\\s*=\\s*\\[\"\\*\"\\]", file("${path.module}/policies.tf"))) == 1
      && length(regexall("(?s)sid\\s*=\\s*\"InspectMicrovmArtifactBuckets\".*?resources\\s*=\\s*\\[\"\\*\"\\]", file("${path.module}/policies.tf"))) == 1
      && length(regexall("(?s)sid\\s*=\\s*\"ListMicrovmBuildArtifacts\".*?resources\\s*=\\s*\\[\"\\*\"\\].*?variable\\s*=\\s*\"s3:prefix\".*?values\\s*=\\s*\\[\"lambda-microvms/\\*\"\\]", file("${path.module}/policies.tf"))) == 1
      && length(regexall("(?s)sid\\s*=\\s*\"PublishMicrovmBuildArtifacts\".*?resources\\s*=\\s*\\[\"\\*\"\\]", file("${path.module}/policies.tf"))) == 1
      && length(regexall("(?s)sid\\s*=\\s*\"PassMicrovmBuildRoles\".*?resources\\s*=\\s*\\[\"\\*\"\\].*?variable\\s*=\\s*\"iam:PassedToService\".*?values\\s*=\\s*\\[\"lambda.amazonaws.com\"\\]", file("${path.module}/policies.tf"))) == 1
      && length(regexall("(?s)sid\\s*=\\s*\"AuthorizeEcrPublication\".*?resources\\s*=\\s*\\[\"\\*\"\\]", file("${path.module}/policies.tf"))) == 1
      && length(regexall("(?s)sid\\s*=\\s*\"PublishAndInspectEcrImages\".*?resources\\s*=\\s*\\[\"\\*\"\\]", file("${path.module}/policies.tf"))) == 1
      && length(regexall("resources\\s*=\\s*\\[\"\\*\"\\]", file("${path.module}/policies.tf"))) == 9
    )
    error_message = "The singleton publisher policy must use wildcard resources for MicroVM publication and Network Connector resolution and passing while retaining the S3 prefix and Lambda PassRole service conditions."
  }
}
