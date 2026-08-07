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

# Optional helper permissions for Forge runners that assume this role to run
# tenant Packer builds and build AMIs in tenant accounts, not the Forge account
# and not the core Forge runner path. The wildcard resource scope is intentional
# because Packer creates and cleans up transient EC2, ECR, and IAM resources. See:
# <https://developer.hashicorp.com/packer/plugins/builders/amazon>.
data "aws_iam_policy_document" "packer_support_for_forge_runners" {
  #checkov:skip=CKV_AWS_107:Forge subscription is an optional ops helper; tenant Packer builds intentionally need broad EC2/ECR/IAM permissions and are not part of the core Forge runner path.
  #checkov:skip=CKV_AWS_109:Forge subscription is an optional ops helper; tenant Packer builds intentionally need broad EC2/ECR/IAM permissions and are not part of the core Forge runner path.
  #checkov:skip=CKV_AWS_110:Tenant Packer builds intentionally use Forge-hosted runners to build AMIs in tenant accounts; ordinary runner workloads do not use this helper path.
  #checkov:skip=CKV_AWS_111:Forge subscription is an optional ops helper; tenant Packer builds intentionally need broad EC2/ECR/IAM permissions and are not part of the core Forge runner path.
  #checkov:skip=CKV_AWS_356:Forge subscription is an optional ops helper; tenant Packer builds intentionally need wildcard resources for transient EC2/ECR/IAM resources and are not part of the core Forge runner path.
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

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  microvm_regions           = var.forge.microvm == null ? tomap({}) : var.forge.microvm.regions
  microvm_image_name_prefix = var.forge.microvm == null ? "" : var.forge.microvm.image_name_prefix

  microvm_image_arns = sort([
    for region, config in local.microvm_regions :
    "arn:${data.aws_partition.current.partition}:lambda:${region}:${data.aws_caller_identity.current.account_id}:microvm-image:${local.microvm_image_name_prefix}-*"
  ])
  microvm_ecr_repository_arns = sort(distinct(flatten([
    for region, config in local.microvm_regions : [
      for repository_name in config.ecr_repository_names :
      "arn:${data.aws_partition.current.partition}:ecr:${region}:${data.aws_caller_identity.current.account_id}:repository/${repository_name}"
    ]
  ])))
}

# IAM is account-global, so Forge owns one managed image-publisher policy for
# configured image/ECR scopes and the regional artifact/build naming convention.
data "aws_iam_policy_document" "microvm_image_management" {
  count = length(local.microvm_regions) > 0 ? 1 : 0

  #checkov:skip=CKV_AWS_111:CreateMicrovmImage and the account-level list operations do not support resource-level permissions.
  #checkov:skip=CKV_AWS_356:CreateMicrovmImage and the account-level list operations require Resource '*'; all resource-aware actions are scoped below.
  statement {
    sid    = "CreateAndDiscoverMicrovmImages"
    effect = "Allow"
    actions = [
      "lambda:CreateMicrovmImage",
      "lambda:ListManagedMicrovmImages",
      "lambda:ListMicrovmImages",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ManageConfiguredMicrovmImages"
    effect = "Allow"
    actions = [
      "lambda:DeleteMicrovmImage",
      "lambda:DeleteMicrovmImageVersion",
      "lambda:GetMicrovmImage",
      "lambda:GetMicrovmImageBuild",
      "lambda:GetMicrovmImageVersion",
      "lambda:ListMicrovmImageBuilds",
      "lambda:ListMicrovmImageVersions",
      "lambda:ListTags",
      "lambda:TagResource",
      "lambda:UntagResource",
      "lambda:UpdateMicrovmImage",
      "lambda:UpdateMicrovmImageVersion",
    ]
    resources = local.microvm_image_arns
  }

  statement {
    sid       = "InspectMicrovmArtifactBuckets"
    effect    = "Allow"
    actions   = ["s3:GetBucketLocation"]
    resources = ["arn:${data.aws_partition.current.partition}:s3:::${data.aws_caller_identity.current.account_id}-forge-microvm-artifacts-*"]
  }

  statement {
    sid       = "ListMicrovmBuildArtifacts"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["arn:${data.aws_partition.current.partition}:s3:::${data.aws_caller_identity.current.account_id}-forge-microvm-artifacts-*"]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["lambda-microvms/*"]
    }
  }

  statement {
    sid    = "PublishMicrovmBuildArtifacts"
    effect = "Allow"
    actions = [
      "s3:AbortMultipartUpload",
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = ["arn:${data.aws_partition.current.partition}:s3:::${data.aws_caller_identity.current.account_id}-forge-microvm-artifacts-*/lambda-microvms/*"]
  }

  statement {
    sid       = "PassMicrovmBuildRoles"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/forge-microvm-build-*"]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["lambda.amazonaws.com"]
    }
  }

  dynamic "statement" {
    for_each = length(local.microvm_ecr_repository_arns) > 0 ? [true] : []
    content {
      sid       = "AuthorizeEcrPublication"
      effect    = "Allow"
      actions   = ["ecr:GetAuthorizationToken"]
      resources = ["*"]
    }
  }

  dynamic "statement" {
    for_each = length(local.microvm_ecr_repository_arns) > 0 ? [true] : []
    content {
      sid    = "PublishAndInspectEcrImages"
      effect = "Allow"
      actions = [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:CompleteLayerUpload",
        "ecr:DescribeImages",
        "ecr:DescribeRepositories",
        "ecr:GetDownloadUrlForLayer",
        "ecr:InitiateLayerUpload",
        "ecr:ListImages",
        "ecr:PutImage",
        "ecr:UploadLayerPart",
      ]
      resources = local.microvm_ecr_repository_arns
    }
  }
}

resource "aws_iam_policy" "microvm_image_management" {
  count = length(local.microvm_regions) > 0 ? 1 : 0

  name        = "forge-microvm-image-management"
  description = "Publish and manage Forge Lambda MicroVM images in configured regional namespaces."
  policy      = data.aws_iam_policy_document.microvm_image_management[0].json
  tags        = local.all_security_tags
}

resource "aws_iam_role_policy_attachment" "microvm_image_management" {
  count = length(local.microvm_regions) > 0 ? 1 : 0

  role       = aws_iam_role.role_for_forge_runners.name
  policy_arn = aws_iam_policy.microvm_image_management[0].arn
}
