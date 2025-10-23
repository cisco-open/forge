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

# Use an external script that:
# 1. Assumes the reader role (first hop)
# 2. From that session, assumes the external source_secret_role_arn (second hop)
# 3. Fetches the secret from source_secret_arn
# 4. Returns the secret value to Terraform as JSON
data "external" "fetch_secret_value" {
  count = var.reader_config.enable_secret_fetch ? 1 : 0

  program = [
    "bash",
    "${path.module}/scripts/fetch_secret_value.sh",
    aws_iam_role.reader.arn,
    var.reader_config.source_secret_role_arn,
    var.reader_config.source_secret_arn,
    var.reader_config.source_secret_region,
    var.aws_profile,
    var.aws_region
  ]

  depends_on = [
    aws_iam_role_policy.allow_assume_external_inline
  ]
}
