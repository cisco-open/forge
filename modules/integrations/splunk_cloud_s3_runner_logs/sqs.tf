resource "aws_sqs_queue" "log_events_queue" {
  name                       = "splunk-s3-runner-logs-events"
  visibility_timeout_seconds = local.lambda_timeout_seconds * 6
  message_retention_seconds  = 86400
  kms_master_key_id          = aws_kms_key.splunk_s3_runner_logs.arn
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.log_events_dlq.arn
    maxReceiveCount     = var.sqs_redrive_max_receive_count
  })
  tags = local.module_tags
}

resource "aws_sqs_queue" "log_events_dlq" {
  name                      = "splunk-s3-runner-logs-events-dlq"
  message_retention_seconds = 1209600 # 14 days
  kms_master_key_id         = aws_kms_key.splunk_s3_runner_logs.arn
  tags                      = merge(local.module_tags, { Purpose = "dlq" })
}

resource "aws_sqs_queue_policy" "allow_s3" {
  queue_url = aws_sqs_queue.log_events_queue.url
  policy    = data.aws_iam_policy_document.allow_s3.json
}

data "aws_iam_policy_document" "allow_s3" {
  statement {
    sid    = "AllowForgeLogBucketsWildcard"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.log_events_queue.arn]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:s3:::*-forge-gh-logs-*"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}
