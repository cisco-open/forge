data "aws_iam_policy_document" "trust" {
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = var.reader_config.role_trust_principals
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "reader" {
  name               = var.reader_config.role_name
  assume_role_policy = data.aws_iam_policy_document.trust.json
  tags               = local.all_security_tags
  tags_all           = local.all_security_tags
}

# Phase 2: Attach policy to assume external role
data "aws_iam_policy_document" "allow_assume_external" {
  count = var.reader_config.enable_secret_fetch ? 1 : 0
  statement {
    sid       = "AllowAssumeExternalRole"
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = [var.reader_config.source_secret_role_arn]
  }
}

resource "aws_iam_role_policy" "allow_assume_external_inline" {
  count  = var.reader_config.enable_secret_fetch ? 1 : 0
  name   = "${aws_iam_role.reader.name}-assume-external"
  role   = aws_iam_role.reader.name
  policy = data.aws_iam_policy_document.allow_assume_external[0].json
}


data "external" "reader_profile" {
  program = [
    "bash",
    "${path.module}/scripts/create_assume_profile.sh",
    aws_iam_role.reader.arn,
    var.aws_profile,
    "reader-temp",
    var.aws_region
  ]

  depends_on = [aws_iam_role.reader]
}


provider "aws" {
  alias   = "external_secret"
  profile = data.external.reader_profile.result.profile
  region  = var.reader_config.source_secret_region

  dynamic "assume_role" {
    for_each = var.reader_config.enable_secret_fetch ? [1] : []
    content {
      role_arn = var.reader_config.source_secret_role_arn
    }
  }
}

data "aws_secretsmanager_secret_version" "target" {
  count     = var.reader_config.enable_secret_fetch ? 1 : 0
  provider  = aws.external_secret
  secret_id = var.reader_config.source_secret_arn
}
