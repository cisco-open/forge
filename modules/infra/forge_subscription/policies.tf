# Policy for allowing EC2 instances R/W access to a subset of specific S3 buckets.
data "aws_iam_policy_document" "s3_access_for_forge_runners" {
  statement {
    effect = "Allow"
    actions = [
      "s3:DeleteObject",
      "s3:GetBucketAcl",
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:GetObjectTagging",
      "s3:GetObjectVersion",
      "s3:ListBucket",
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:PutObjectTagging",
    ]
    resources = [
      "*", # Allow access to all objects in the ops buckets.
    ]
  }
}

# Policy for allowing EC2 instances R/O access to a subset of Secrets Manager secrets.
# These are mainly for supplying certain short-lived run-time credentials to
# EC2 instances so that cloud-init can fully bootstrap the instance.
data "aws_iam_policy_document" "secrets_access_for_forge_runners" {
  statement {
    actions = [
      "secretsmanager:ListSecrets",
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
    ]
    resources = [
      "*"
    ]
  }
}

# Permissions needed for Packer builds. See:
# <https://developer.hashicorp.com/packer/plugins/builders/amazon>.
data "aws_iam_policy_document" "packer_support_for_forge_runners" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:AttachVolume",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:CopyImage",
      "ec2:CreateFleet",
      "ec2:CreateImage",
      "ec2:CreateKeypair",
      "ec2:CreateLaunchTemplate",
      "ec2:CreateSecurityGroup",
      "ec2:CreateSnapshot",
      "ec2:CreateTags",
      "ec2:CreateVolume",
      "ec2:DeleteKeyPair",
      "ec2:DeleteLaunchTemplate",
      "ec2:DeleteSecurityGroup",
      "ec2:DeleteSnapshot",
      "ec2:DeleteVolume",
      "ec2:DeregisterImage",
      "ec2:DescribeHosts",
      "ec2:DescribeImageAttribute",
      "ec2:DescribeImages",
      "ec2:DescribeInstanceStatus",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceTypeOfferings",
      "ec2:DescribeRegions",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSnapshots",
      "ec2:DescribeSpotPriceHistory",
      "ec2:DescribeSubnets",
      "ec2:DescribeTags",
      "ec2:DescribeVolumes",
      "ec2:DescribeVpcs",
      "ec2:DetachVolume",
      "ec2:GetPasswordData",
      "ec2:ModifyImageAttribute",
      "ec2:ModifyInstanceAttribute",
      "ec2:ModifySnapshotAttribute",
      "ec2:RegisterImage",
      "ec2:RunInstances",
      "ec2:StopInstances",
      "ec2:TerminateInstances",
    ]
    resources = [
      "*"
    ]
  }

  statement {
    sid    = "EcsTaskPolicy"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:DescribeImages",
      "ecr:DescribeImageScanFindings",
      "ecr:DescribeRepositories",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetLifecyclePolicy",
      "ecr:GetLifecyclePolicyPreview",
      "ecr:GetRepositoryPolicy",
      "ecr:ListImages",
      "ecr:ListTagsForResource",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [
      "*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "iam:GetInstanceProfile",
      "iam:PassRole",
    ]
    resources = [
      "*"
    ]
  }
}

# Attach policies to the role.
resource "aws_iam_role_policy" "s3_access_for_forge_runners" {
  name   = "allow_scoped_s3_access_for_forge_runners"
  role   = aws_iam_role.role_for_forge_runners.id
  policy = data.aws_iam_policy_document.s3_access_for_forge_runners.json
}

resource "aws_iam_role_policy" "secrets_access_for_forge_runners" {
  name   = "allow_scoped_secrets_access_for_forge_runners"
  role   = aws_iam_role.role_for_forge_runners.id
  policy = data.aws_iam_policy_document.secrets_access_for_forge_runners.json
}

resource "aws_iam_role_policy" "packer_support_for_forge_runners" {
  name   = "allow_scoped_packer_support_for_forge_runners"
  role   = aws_iam_role.role_for_forge_runners.id
  policy = data.aws_iam_policy_document.packer_support_for_forge_runners.json
}
