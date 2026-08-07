mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Action\":[\"sts:AssumeRole\",\"s3:GetObject\",\"secretsmanager:GetSecretValue\",\"ec2:CreateImage\",\"ecr:GetAuthorizationToken\",\"lambda:CreateMicrovmImage\"],\"Effect\":\"Allow\",\"Resource\":\"*\"}]}"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
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
    microvm = {
      image_name_prefix = "srea-gh-runner-ubuntu-arm64"
      regions = {
        eu-west-1 = {
          artifact_bucket_name = "forge-microvm-test-eu-west-1"
          ecr_repository_names = [
            "actions-runner-base-image",
            "mirror-hardened-ubuntu24",
          ]
        }
        us-east-1 = {
          artifact_bucket_name = "forge-microvm-test-us-east-1"
          ecr_repository_names = [
            "actions-runner-base-image",
          ]
        }
      }
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
      && length(aws_iam_policy.microvm_image_management) == 1
      && aws_iam_policy.microvm_image_management[0].name == "forge-microvm-image-management"
      && strcontains(aws_iam_policy.microvm_image_management[0].policy, "lambda:CreateMicrovmImage")
      && length(aws_iam_role_policy_attachment.microvm_image_management) == 1
      && aws_iam_role_policy_attachment.microvm_image_management[0].role == aws_iam_role.role_for_forge_runners.name
      && aws_iam_role_policy_attachment.microvm_image_management[0].policy_arn == aws_iam_policy.microvm_image_management[0].arn
    )
    error_message = "Forge subscription must keep its existing inline policies and attach one account-wide MicroVM image-management policy to role_for_forge_runners."
  }

  assert {
    condition = (
      local.microvm_image_arns == tolist([
        "arn:aws:lambda:eu-west-1:123456789012:microvm-image:srea-gh-runner-ubuntu-arm64-*",
        "arn:aws:lambda:us-east-1:123456789012:microvm-image:srea-gh-runner-ubuntu-arm64-*",
      ])
      && local.microvm_artifact_bucket_arns == tolist([
        "arn:aws:s3:::forge-microvm-test-eu-west-1",
        "arn:aws:s3:::forge-microvm-test-us-east-1",
      ])
      && local.microvm_artifact_object_arns == tolist([
        "arn:aws:s3:::forge-microvm-test-eu-west-1/lambda-microvms/*",
        "arn:aws:s3:::forge-microvm-test-us-east-1/lambda-microvms/*",
      ])
      && local.microvm_build_role_arns == tolist([
        "arn:aws:iam::123456789012:role/forge-microvm-build-eu-west-1",
        "arn:aws:iam::123456789012:role/forge-microvm-build-us-east-1",
      ])
      && local.microvm_ecr_repository_arns == tolist([
        "arn:aws:ecr:eu-west-1:123456789012:repository/actions-runner-base-image",
        "arn:aws:ecr:eu-west-1:123456789012:repository/mirror-hardened-ubuntu24",
        "arn:aws:ecr:us-east-1:123456789012:repository/actions-runner-base-image",
      ])
      && local.microvm_region_names == tolist([
        "eu-west-1",
        "us-east-1",
      ])
    )
    error_message = "The account-wide MicroVM policy must derive exact regional image, artifact, build-role, and ECR scopes from Forge configuration."
  }

  assert {
    condition = (
      length(regexall("(?s)sid\\s*=\\s*\"CreateAndDiscoverMicrovmImages\".*?resources\\s*=\\s*\\[\"\\*\"\\].*?variable\\s*=\\s*\"aws:RequestedRegion\".*?values\\s*=\\s*local\\.microvm_region_names", file("${path.module}/policies.tf"))) == 1
      && length(regexall("(?s)sid\\s*=\\s*\"ListMicrovmBuildArtifacts\".*?resources\\s*=\\s*local\\.microvm_artifact_bucket_arns.*?variable\\s*=\\s*\"s3:prefix\".*?values\\s*=\\s*\\[\"lambda-microvms/\\*\"\\]", file("${path.module}/policies.tf"))) == 1
      && length(regexall("(?s)sid\\s*=\\s*\"PassMicrovmBuildRoles\".*?resources\\s*=\\s*local\\.microvm_build_role_arns.*?variable\\s*=\\s*\"iam:PassedToService\".*?values\\s*=\\s*\\[\"lambda.amazonaws.com\"\\]", file("${path.module}/policies.tf"))) == 1
      && length(regexall("(?s)sid\\s*=\\s*\"AuthorizeEcrPublication\".*?resources\\s*=\\s*\\[\"\\*\"\\].*?variable\\s*=\\s*\"aws:RequestedRegion\".*?values\\s*=\\s*local\\.microvm_region_names", file("${path.module}/policies.tf"))) == 1
      && length(regexall("(?s)sid\\s*=\\s*\"PublishAndInspectEcrImages\".*?resources\\s*=\\s*local\\.microvm_ecr_repository_arns", file("${path.module}/policies.tf"))) == 1
    )
    error_message = "The singleton publisher policy must retain regional conditions and exact S3, build-role, and ECR scopes."
  }
}

run "legacy_config_omits_microvm" {
  command = plan

  variables {
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

  assert {
    condition = (
      length(data.aws_iam_policy_document.microvm_image_management) == 0
      && length(aws_iam_policy.microvm_image_management) == 0
      && length(aws_iam_role_policy_attachment.microvm_image_management) == 0
    )
    error_message = "Existing Forge subscription callers that omit microvm must remain valid and create no MicroVM policy or attachment."
  }
}

run "rejects_invalid_microvm_image_prefix" {
  command = plan

  variables {
    forge = {
      runner_roles = [
        "arn:aws:iam::210987654321:role/forge-runner"
      ]
      ecr_repositories = {
        names                  = []
        ecr_access_account_ids = []
        regions                = []
      }
      microvm = {
        image_name_prefix = "not/a/microvm/image"
        regions = {
          eu-west-1 = {
            artifact_bucket_name = "forge-microvm-test-eu-west-1"
          }
        }
      }
    }
  }

  expect_failures = [var.forge]
}

run "rejects_empty_microvm_regions" {
  command = plan

  variables {
    forge = {
      runner_roles = [
        "arn:aws:iam::210987654321:role/forge-runner"
      ]
      ecr_repositories = {
        names                  = []
        ecr_access_account_ids = []
        regions                = []
      }
      microvm = {
        image_name_prefix = "srea-gh-runner-ubuntu-arm64"
        regions           = {}
      }
    }
  }

  expect_failures = [var.forge]
}
