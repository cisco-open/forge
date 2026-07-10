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
  command = plan

  assert {
    condition     = aws_ebs_encryption_by_default.gpol_encrypt_ebs.enabled == false
    error_message = "AMI policy helper must preserve the current default EBS encryption setting until a KMS strategy is introduced."
  }

  assert {
    condition = (
      aws_iam_role.dlm_lifecycle_role.name == "dlm-lifecycle-role"
      && strcontains(aws_iam_role.dlm_lifecycle_role.assume_role_policy, "dlm.amazonaws.com")
      && aws_iam_role_policy.dlm_lifecycle.name == "dlm-lifecycle-policy"
      && aws_iam_role.dlm_lifecycle_role.tags.Product == "Forge"
      && aws_iam_role.dlm_lifecycle_role.tags.Env == "test"
    )
    error_message = "AMI lifecycle role must remain dedicated to AWS DLM and carry merged security tags."
  }

  assert {
    condition = (
      strcontains(aws_iam_role_policy.dlm_lifecycle.policy, "ec2:CreateSnapshot")
      && strcontains(aws_iam_role_policy.dlm_lifecycle.policy, "ec2:CreateSnapshots")
      && strcontains(aws_iam_role_policy.dlm_lifecycle.policy, "ec2:DeleteSnapshot")
      && strcontains(aws_iam_role_policy.dlm_lifecycle.policy, "ec2:DescribeInstances")
      && strcontains(aws_iam_role_policy.dlm_lifecycle.policy, "ec2:DescribeVolumes")
      && strcontains(aws_iam_role_policy.dlm_lifecycle.policy, "ec2:DescribeSnapshots")
      && strcontains(aws_iam_role_policy.dlm_lifecycle.policy, "ec2:CreateTags")
      && strcontains(aws_iam_role_policy.dlm_lifecycle.policy, "arn:aws:ec2:*::snapshot/*")
    )
    error_message = "AMI lifecycle policy must keep snapshot create/delete/tag permissions."
  }

  assert {
    condition = (
      aws_dlm_lifecycle_policy.dlm_lifecycle.state == "ENABLED"
      && aws_dlm_lifecycle_policy.dlm_lifecycle.execution_role_arn == aws_iam_role.dlm_lifecycle_role.arn
      && aws_dlm_lifecycle_policy.dlm_lifecycle.policy_details[0].resource_types[0] == "VOLUME"
      && aws_dlm_lifecycle_policy.dlm_lifecycle.policy_details[0].schedule[0].create_rule[0].interval == 24
      && aws_dlm_lifecycle_policy.dlm_lifecycle.policy_details[0].schedule[0].create_rule[0].interval_unit == "HOURS"
      && aws_dlm_lifecycle_policy.dlm_lifecycle.policy_details[0].schedule[0].create_rule[0].times[0] == "23:45"
      && aws_dlm_lifecycle_policy.dlm_lifecycle.policy_details[0].schedule[0].retain_rule[0].count == 60
      && aws_dlm_lifecycle_policy.dlm_lifecycle.policy_details[0].schedule[0].tags_to_add.SnapshotCreator == "DLM"
      && aws_dlm_lifecycle_policy.dlm_lifecycle.policy_details[0].schedule[0].tags_to_add.IsLifeCycled == "yes"
      && aws_dlm_lifecycle_policy.dlm_lifecycle.policy_details[0].schedule[0].copy_tags == false
      && aws_dlm_lifecycle_policy.dlm_lifecycle.policy_details[0].target_tags.role == "github-runner"
      && aws_dlm_lifecycle_policy.dlm_lifecycle.tags.Product == "Forge"
      && aws_dlm_lifecycle_policy.dlm_lifecycle.tags.Env == "test"
    )
    error_message = "AMI DLM lifecycle must keep daily runner-volume snapshots, retention, snapshot tags, execution role, and merged security tags."
  }
}
