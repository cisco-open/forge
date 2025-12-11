# Define the IAM policy for role assumption
data "aws_iam_policy_document" "role_assumption_for_forge_runners" {
  count = length(var.deployment_config.tenant.iam_roles_to_assume) > 0 ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
      "sts:TagSession",
    ]
    resources = var.deployment_config.tenant.iam_roles_to_assume
  }
}

# Define the actual IAM policy for role assumption
resource "aws_iam_policy" "role_assumption_for_forge_runners" {
  count = length(var.deployment_config.tenant.iam_roles_to_assume) > 0 ? 1 : 0

  name        = "${var.deployment_config.deployment_prefix}-policy-for-role-assumption-for-forge_runners"
  description = "Managed policy for IAM role assumption."
  policy      = element(data.aws_iam_policy_document.role_assumption_for_forge_runners[*].json, 0)

  tags     = local.all_security_tags
  tags_all = local.all_security_tags
}

# Define the IAM policy for ECR access
data "aws_iam_policy_document" "ecr_access_for_ec2_instances" {
  statement {
    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:DescribeImages",
      "ecr:GetAuthorizationToken",
      "ecr:ListImages"
    ]
    resources = [
      "*"
    ]
  }
}

# Define the actual IAM policy for ECR access
resource "aws_iam_policy" "ecr_access_for_ec2_instances" {
  name        = "${var.deployment_config.deployment_prefix}-policy-for-ecr-access-for-ec2-instances"
  description = "Managed policy for IAM role assumption."
  policy      = data.aws_iam_policy_document.ecr_access_for_ec2_instances.json

  tags     = local.all_security_tags
  tags_all = local.all_security_tags
}
