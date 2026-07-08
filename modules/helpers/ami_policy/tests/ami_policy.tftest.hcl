mock_provider "aws" {
  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/dlm-lifecycle-role"
      id  = "dlm-lifecycle-role"
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

run "ami_lifecycle_policy_contract" {
  assert {
    condition     = aws_ebs_encryption_by_default.gpol_encrypt_ebs.enabled == false
    error_message = "AMI policy helper must preserve the current default EBS encryption setting until a KMS strategy is introduced."
  }

  assert {
    condition = (
      aws_iam_role.dlm_lifecycle_role.name == "dlm-lifecycle-role"
      && strcontains(aws_iam_role.dlm_lifecycle_role.assume_role_policy, "dlm.amazonaws.com")
      && aws_iam_role_policy.dlm_lifecycle.name == "dlm-lifecycle-policy"
    )
    error_message = "AMI lifecycle role must remain dedicated to AWS DLM."
  }

  assert {
    condition = (
      strcontains(aws_iam_role_policy.dlm_lifecycle.policy, "ec2:CreateSnapshot")
      && strcontains(aws_iam_role_policy.dlm_lifecycle.policy, "ec2:DeleteSnapshot")
      && strcontains(aws_iam_role_policy.dlm_lifecycle.policy, "arn:aws:ec2:*::snapshot/*")
    )
    error_message = "AMI lifecycle policy must keep snapshot create/delete/tag permissions."
  }

  assert {
    condition = (
      aws_dlm_lifecycle_policy.dlm_lifecycle.state == "ENABLED"
      && aws_dlm_lifecycle_policy.dlm_lifecycle.policy_details[0].resource_types[0] == "VOLUME"
      && aws_dlm_lifecycle_policy.dlm_lifecycle.policy_details[0].schedule[0].create_rule[0].interval == 24
      && aws_dlm_lifecycle_policy.dlm_lifecycle.policy_details[0].schedule[0].retain_rule[0].count == 60
      && aws_dlm_lifecycle_policy.dlm_lifecycle.policy_details[0].target_tags.role == "github-runner"
    )
    error_message = "AMI DLM lifecycle must keep daily volume snapshots retained for roughly two months and targeted to runner volumes."
  }
}
