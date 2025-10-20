data "aws_iam_policy_document" "cloud_custodian_policy" {
  version = "2012-10-17"

  statement {
    actions = [
      "ec2:DescribeSecurityGroups",
      "ec2:DeleteSecurityGroup",
      "ec2:DescribeKeyPairs",
      "ec2:DeleteKeyPair",
      "ec2:DescribeImages",
      "ec2:DeregisterImage",
      "ec2:DescribeSnapshots",
      "ec2:DeleteSnapshot",
      "ec2:DescribeInstances",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:DescribeSecurityGroupReferences",
      "ec2:DescribeVolumes",
      "ec2:DeleteVolume",
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "lambda:ListFunctions",
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "codebuild:ListProjects",
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "batch:DescribeComputeEnvironments",
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "events:ListEventBuses",
      "events:ListRules",
      "events:ListTargetsByRule",
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeLaunchConfigurations",
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:BatchGetImage",
      "ecr:DescribeImageScanFindings",
      "ecr:GetLifecyclePolicy",
      "ecr:ListTagsForResource",
      "ecr:GetRepositoryPolicy"
    ]
    resources = ["*"]
  }

}

resource "aws_iam_policy" "cloud_custodian_policy" {
  name        = "CloudCustodianPolicy"
  description = "Cloud Custodian Policy for managing EC2 resources"
  policy      = data.aws_iam_policy_document.cloud_custodian_policy.json
  tags        = local.all_security_tags
  tags_all    = local.all_security_tags
}

data "aws_iam_policy_document" "assume_role_for_cloud_custodian" {

  # Allow GH runners to assume dedicated role.
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
      "sts:TagSession",
    ]
    principals {
      type        = "AWS"
      identifiers = [var.forge_role_arn]
    }
  }
}

resource "aws_iam_role_policy_attachment" "attach_cloud_custodian_policy" {
  role       = aws_iam_role.cloud_custodian.name
  policy_arn = aws_iam_policy.cloud_custodian_policy.arn
}

resource "aws_iam_role" "cloud_custodian" {
  name                 = "cloud_custodian"
  assume_role_policy   = data.aws_iam_policy_document.assume_role_for_cloud_custodian.json
  max_session_duration = 21600 # Allow role to last for up to 6 hours.

  tags     = local.all_security_tags
  tags_all = local.all_security_tags
}
