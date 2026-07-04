# Helper policy for Forge runners that assume this role in tenant accounts.
# Allows runner jobs to operate on tenant ops S3 buckets, not Forge-account buckets.
data "aws_iam_policy_document" "s3_access_for_forge_runners" {
  #checkov:skip=CKV_AWS_108:Forge subscription is an ops helper; tenant ops buckets are created outside this module and runners assume this tenant role to operate on them.
  #checkov:skip=CKV_AWS_109:Forge subscription is an ops helper; tenant ops buckets are created outside this module and runners assume this tenant role to operate on them.
  #checkov:skip=CKV_AWS_111:Forge subscription is an ops helper; tenant ops buckets are created outside this module and runners assume this tenant role to operate on them.
  #checkov:skip=CKV_AWS_356:Forge subscription is an ops helper; tenant ops buckets are created outside this module and runners assume this tenant role to operate on them.
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

# Helper policy for Forge runners that assume this role in tenant accounts.
# Allows runner jobs to read tenant Secrets Manager values needed for operations.
data "aws_iam_policy_document" "secrets_access_for_forge_runners" {
  #checkov:skip=CKV_AWS_108:Forge subscription is an ops helper; tenant secrets are operator-defined and runners assume this tenant role to discover required values.
  #checkov:skip=CKV_AWS_356:Forge subscription is an ops helper; tenant secrets are operator-defined and runners assume this tenant role to discover required values.
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

# Helper permissions for Forge runners that assume this role to run tenant
# Packer builds and build AMIs in tenant accounts, not the Forge account. See:
# <https://developer.hashicorp.com/packer/plugins/builders/amazon>.
data "aws_iam_policy_document" "packer_support_for_forge_runners" {
  #checkov:skip=CKV_AWS_107:Forge subscription is an ops helper; tenant Packer builds need broad EC2/ECR/IAM permissions from Forge-hosted runners in tenant accounts.
  #checkov:skip=CKV_AWS_109:Forge subscription is an ops helper; tenant Packer builds need broad EC2/ECR/IAM permissions from Forge-hosted runners in tenant accounts.
  #checkov:skip=CKV_AWS_110:Tenant Packer builds intentionally use Forge-hosted runners to build AMIs in tenant accounts; runner workloads do not use this path directly.
  #checkov:skip=CKV_AWS_111:Forge subscription is an ops helper; tenant Packer builds need broad EC2/ECR/IAM permissions from Forge-hosted runners in tenant accounts.
  #checkov:skip=CKV_AWS_356:Forge subscription is an ops helper; tenant Packer builds need broad EC2/ECR/IAM permissions from Forge-hosted runners in tenant accounts.
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
