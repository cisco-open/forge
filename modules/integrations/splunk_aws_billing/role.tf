data "aws_iam_policy_document" "lambda_policy_document" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    effect    = "Allow"
    resources = ["arn:aws:logs:*:*:*"]
  }

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

resource "aws_iam_policy" "lambda_policy" {
  name        = "cur-to-splunk-lambda-policy"
  description = "Policy for Lambda to access S3 and CloudWatch logs"
  policy      = data.aws_iam_policy_document.lambda_policy_document.json
}

resource "aws_iam_role_policy_attachment" "attach_policy" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "cur-to-splunk-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}
