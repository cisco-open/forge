data "aws_iam_policy_document" "lambda_policy_document" {

  statement {
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.aws_billing_report.id}",
      "arn:aws:s3:::${aws_s3_bucket.aws_billing_report.id}/*"
    ]
  }

  statement {
    actions = [
      "s3:PutObject",
    ]
    effect = "Allow"
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.aws_billing_report.id}/tmp/*"
    ]
  }

  statement {
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    effect = "Allow"
    resources = [
      for s in data.aws_secretsmanager_secret.secrets : s.arn
    ]
  }

  statement {
    actions = [
      "kms:Decrypt"
    ]
    effect = "Allow"
    resources = [
      for s in data.aws_secretsmanager_secret.secrets : s.kms_key_id
    ]
  }
}
