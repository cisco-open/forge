data "aws_iam_policy_document" "cloudformation_assume_role_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["cloudformation.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cloudformation_admin_role" {
  name = "AWSCloudFormationStackSetAdministrationRole"

  assume_role_policy = data.aws_iam_policy_document.cloudformation_assume_role_policy.json

  tags     = local.all_security_tags
  tags_all = local.all_security_tags
}

data "aws_iam_policy_document" "admin_assume_execution_role_policy" {
  statement {
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = ["arn:aws:iam::*:role/AWSCloudFormationStackSetExecutionRole"]
  }
}

resource "aws_iam_role_policy" "admin_assume_execution_role_policy_attachment" {
  name = "AWSCloudFormationStackSetAdministrationRolePolicy"
  role = aws_iam_role.cloudformation_admin_role.id

  policy = data.aws_iam_policy_document.admin_assume_execution_role_policy.json
}

data "aws_iam_policy_document" "execution_assume_admin_role_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/AWSCloudFormationStackSetAdministrationRole"]
    }
  }
}

resource "aws_iam_role" "cloudformation_execution_role" {
  name = "AWSCloudFormationStackSetExecutionRole"

  assume_role_policy = data.aws_iam_policy_document.execution_assume_admin_role_policy.json

  tags     = local.all_security_tags
  tags_all = local.all_security_tags
}

# Optional helper policy, not part of the core Forge runner path. CloudFormation
# StackSet execution requires broad service and resource coverage for
# operator-managed stacks, so wildcard findings here are intentional.
data "aws_iam_policy_document" "execution_role_policy" {
  #checkov:skip=CKV2_AWS_40:Optional CloudFormation helper intentionally grants broad StackSet execution permissions for operator-managed stacks; this is not part of the core Forge runner path.
  #checkov:skip=CKV_AWS_107:Optional CloudFormation helper intentionally grants broad StackSet execution permissions for operator-managed stacks; this is not part of the core Forge runner path.
  #checkov:skip=CKV_AWS_108:Optional CloudFormation helper intentionally grants broad StackSet execution permissions for operator-managed stacks; this is not part of the core Forge runner path.
  #checkov:skip=CKV_AWS_109:Optional CloudFormation helper intentionally grants broad StackSet execution permissions for operator-managed stacks; this is not part of the core Forge runner path.
  #checkov:skip=CKV_AWS_110:Optional CloudFormation helper intentionally grants broad StackSet execution permissions for operator-managed stacks; this is not part of the core Forge runner path.
  #checkov:skip=CKV_AWS_111:Optional CloudFormation helper intentionally grants broad StackSet execution permissions for operator-managed stacks; this is not part of the core Forge runner path.
  #checkov:skip=CKV_AWS_356:Optional CloudFormation helper intentionally needs wildcard resources for StackSet-managed tenant resources; this is not part of the core Forge runner path.
  statement {
    effect = "Allow"
    actions = [
      "cloudformation:*",
      "s3:*",
      "ec2:*",
      "iam:*",
      "lambda:*",
      "dynamodb:*",
      "rds:*",
      "sns:*",
      "sqs:*",
      "logs:*",
      "events:*",
      "kms:*",
      "ssm:*",
      "firehose:*",
      "secretsmanager:*",
      "autoscaling:*",
      "elasticloadbalancing:*",
      "cloudwatch:*",
      "tag:GetResources",
      "tag:TagResources",
      "tag:UntagResources"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "execution_role_policy_attachment" {
  name = "AWSCloudFormationStackSetExecutionRolePolicy"
  role = aws_iam_role.cloudformation_execution_role.id

  policy = data.aws_iam_policy_document.execution_role_policy.json
}
