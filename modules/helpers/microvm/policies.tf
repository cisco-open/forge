# Lambda assumes this role while building an image snapshot.
data "aws_iam_policy_document" "build" {
  statement {
    sid       = "ReadRegionalBuildArtifact"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.artifacts.arn}/${local.artifact_prefix}/*"]
  }

  statement {
    sid       = "CreateMicrovmBuildLogGroups"
    effect    = "Allow"
    actions   = ["logs:CreateLogGroup"]
    resources = [local.log_group_arn_pattern]
  }

  statement {
    sid    = "WriteMicrovmBuildLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [local.log_stream_arn_pattern]
  }

  dynamic "statement" {
    for_each = length(var.ecr_repository_arns) > 0 ? [true] : []
    content {
      sid       = "AuthorizePrivateEcrPull"
      effect    = "Allow"
      actions   = ["ecr:GetAuthorizationToken"]
      resources = ["*"]
    }
  }

  dynamic "statement" {
    for_each = length(var.ecr_repository_arns) > 0 ? [true] : []
    content {
      sid    = "PullPrivateEcrImage"
      effect = "Allow"
      actions = [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer",
      ]
      resources = var.ecr_repository_arns
    }
  }

}

resource "aws_iam_policy" "build" {
  name        = "forge-microvm-build-${var.aws_region}"
  description = "Regional permissions used by Lambda while building Forge MicroVM images."
  policy      = data.aws_iam_policy_document.build.json
  tags        = local.all_security_tags
}

resource "aws_iam_role_policy_attachment" "build" {
  role       = aws_iam_role.build.name
  policy_arn = aws_iam_policy.build.arn
}

# Create and account-level list actions do not support resource-level IAM
# scoping. All operations that accept a MicroVM image resource are restricted
# to the publisher-owned image namespace reserved by this module.
data "aws_iam_policy_document" "image_management" {
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
    resources = [local.image_arn_pattern]
  }

  statement {
    sid       = "InspectRegionalArtifactBucket"
    effect    = "Allow"
    actions   = ["s3:GetBucketLocation"]
    resources = [aws_s3_bucket.artifacts.arn]
  }

  statement {
    sid       = "ListRegionalBuildArtifacts"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.artifacts.arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${local.artifact_prefix}/*"]
    }
  }

  statement {
    sid    = "PublishRegionalBuildArtifacts"
    effect = "Allow"
    actions = [
      "s3:AbortMultipartUpload",
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = ["${aws_s3_bucket.artifacts.arn}/${local.artifact_prefix}/*"]
  }

  statement {
    sid       = "PassMicrovmBuildRole"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.build.arn]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["lambda.amazonaws.com"]
    }
  }

  dynamic "statement" {
    for_each = length(var.ecr_repository_arns) > 0 ? [true] : []
    content {
      sid       = "AuthorizeEcrPublication"
      effect    = "Allow"
      actions   = ["ecr:GetAuthorizationToken"]
      resources = ["*"]
    }
  }

  dynamic "statement" {
    for_each = length(var.ecr_repository_arns) > 0 ? [true] : []
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
      resources = var.ecr_repository_arns
    }
  }

}

resource "aws_iam_policy" "image_management" {
  name        = "forge-microvm-image-management-${var.aws_region}"
  description = "Publish and manage Forge Lambda MicroVM images in the reserved regional image namespace."
  policy      = data.aws_iam_policy_document.image_management.json
  tags        = local.all_security_tags
}

# This regional policy owns exact image-namespace, artifact-bucket, build-role,
# and ECR scopes. It remains unattached here; forge_subscription attaches
# regional policy ARNs directly to role_for_forge_runners.

# Consumer modules can attach this policy to a control-plane role they own.
# This helper deliberately leaves the managed policy unattached.
data "aws_iam_policy_document" "usage" {
  statement {
    sid    = "UseConfiguredMicrovmImages"
    effect = "Allow"
    actions = [
      "lambda:CreateMicrovmAuthToken",
      "lambda:GetMicrovm",
      "lambda:GetMicrovmImage",
      "lambda:GetMicrovmImageVersion",
      "lambda:ListMicrovmImageVersions",
      "lambda:ResumeMicrovm",
      "lambda:RunMicrovm",
      "lambda:SuspendMicrovm",
      "lambda:TerminateMicrovm",
    ]
    resources = [local.image_arn_pattern]
  }

  #checkov:skip=CKV_AWS_111:ListMicrovms and ListMicrovmImages do not support resource-level permissions.
  #checkov:skip=CKV_AWS_356:Lambda MicroVM account-level list actions require Resource '*'.
  statement {
    sid    = "DiscoverMicrovmRuntimeState"
    effect = "Allow"
    actions = [
      "lambda:ListMicrovmImages",
      "lambda:ListMicrovms",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "ReadConfiguredNetworkConnectors"
    effect    = "Allow"
    actions   = ["lambda:GetNetworkConnector"]
    resources = values(local.connector_arns)
  }

  #checkov:skip=CKV_AWS_111:PassNetworkConnector and ListNetworkConnectors do not support resource-level permissions.
  #checkov:skip=CKV_AWS_356:Lambda requires Resource '*' for PassNetworkConnector and the account-level list operation.
  statement {
    sid    = "PassAndDiscoverNetworkConnectors"
    effect = "Allow"
    actions = [
      "lambda:ListNetworkConnectors",
      "lambda:PassNetworkConnector",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "usage" {
  name        = "forge-microvm-runtime-usage-${var.aws_region}"
  description = "Reusable permissions for operating Forge runner MicroVM images in the reserved namespace and passing their regional Network Connectors."
  policy      = data.aws_iam_policy_document.usage.json
  tags        = local.all_security_tags
}
