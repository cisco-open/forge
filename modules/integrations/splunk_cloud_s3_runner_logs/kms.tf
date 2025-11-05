data "aws_iam_policy_document" "kms_s3" {
  # Root full access
  statement {
    sid    = "AllowRootAccountFullAccess"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  # CloudWatch Logs – actions that can use EncryptionContext
  statement {
    sid    = "AllowCloudWatchLogsUseKeyWithContext"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["logs.${var.aws_region}.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*"
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/kinesisfirehose/${local.prefix_firehose}-${var.aws_region}"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  # CloudWatch Logs – DescribeKey (cannot use EncryptionContext)
  statement {
    sid    = "AllowCloudWatchLogsDescribeKey"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["logs.${var.aws_region}.amazonaws.com"]
    }
    actions   = ["kms:DescribeKey"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  # S3 → SQS: encrypt/decrypt/generate keys (per bucket)
  dynamic "statement" {
    for_each = local.bucket_list
    content {
      sid    = "AllowS3SendMessage-${statement.value.name}-WithContext"
      effect = "Allow"
      principals {
        type        = "Service"
        identifiers = ["s3.amazonaws.com"]
      }

      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:GenerateDataKey*"
      ]
      resources = ["*"]

      condition {
        test     = "StringEquals"
        variable = "aws:SourceArn"
        values   = ["arn:aws:s3:::${statement.value.name}"]
      }
      condition {
        test     = "StringEquals"
        variable = "aws:SourceAccount"
        values   = [data.aws_caller_identity.current.account_id]
      }
      condition {
        test     = "StringEquals"
        variable = "kms:ViaService"
        values   = ["sqs.${var.aws_region}.amazonaws.com"]
      }
      condition {
        test     = "StringEquals"
        variable = "kms:CallerAccount"
        values   = [data.aws_caller_identity.current.account_id]
      }
    }
  }

  # S3 → SQS: DescribeKey (cannot use unsupported conditions)
  dynamic "statement" {
    for_each = local.bucket_list
    content {
      sid    = "AllowS3SendMessage-${statement.value.name}-DescribeKey"
      effect = "Allow"
      principals {
        type        = "Service"
        identifiers = ["s3.amazonaws.com"]
      }
      actions   = ["kms:DescribeKey"]
      resources = ["*"]

      condition {
        test     = "StringEquals"
        variable = "aws:SourceAccount"
        values   = [data.aws_caller_identity.current.account_id]
      }
    }
  }

  statement {
    sid    = "AllowS3SendMessageToSQS"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt",
      "kms:GenerateDataKey*"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:s3:::*-forge-gh-logs-*"]
    }
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["sqs.${var.aws_region}.amazonaws.com"]
    }
  }
}

resource "aws_kms_key" "splunk_s3_runner_logs" {
  description             = "KMS key for GitHub logs ingestion pipeline"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = var.tags
  policy                  = data.aws_iam_policy_document.kms_s3.json
}

resource "aws_kms_alias" "splunk_s3_runner_logs" {
  name          = "alias/splunk-s3-runner-logs"
  target_key_id = aws_kms_key.splunk_s3_runner_logs.arn
}
