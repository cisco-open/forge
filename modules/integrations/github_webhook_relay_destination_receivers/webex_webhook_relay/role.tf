data "aws_iam_policy_document" "secret" {
  statement {
    sid       = "DecryptCICDSecrets"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.webex.arn]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["secretsmanager.${var.aws_region}.amazonaws.com"]
    }
  }

  statement {
    sid     = "ReadCICDSecrets"
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      for k, s in aws_secretsmanager_secret.cicd_secrets : "${s.arn}*"
    ]
  }
}
