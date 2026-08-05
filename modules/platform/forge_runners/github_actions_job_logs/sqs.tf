resource "aws_sqs_queue" "jobs_dlq" {
  #checkov:skip=CKV_AWS_27:SQS customer-managed KMS encryption is deferred until job-log queue encryption is tested with Lambda producers and consumers.
  name                       = "${var.prefix}-gha-job-logs-dead-letter"
  message_retention_seconds  = 1209600 # 14 days
  visibility_timeout_seconds = 30
  tags                       = var.tags
  tags_all                   = var.tags
}

resource "aws_sqs_queue" "jobs" {
  #checkov:skip=CKV_AWS_27:SQS customer-managed KMS encryption is deferred until job-log queue encryption is tested with Lambda producers and consumers.
  name = "${var.prefix}-gha-job-logs"
  # Must be >= Lambda timeout (900s) otherwise CreateEventSourceMapping fails.
  visibility_timeout_seconds = 910
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.jobs_dlq.arn
    maxReceiveCount     = 10
  })
  tags     = var.tags
  tags_all = var.tags
}

resource "aws_sqs_queue" "s3_notifications" {
  name                      = "${var.prefix}-forge-gh-logs-events"
  message_retention_seconds = 1209600 # 14 days
  sqs_managed_sse_enabled   = true
  tags                      = var.tags
  tags_all                  = var.tags
}

resource "aws_sqs_queue_policy" "s3_notifications" {
  queue_url = aws_sqs_queue.s3_notifications.url
  policy    = data.aws_iam_policy_document.s3_notifications.json
}

data "aws_iam_policy_document" "s3_notifications" {
  statement {
    sid    = "AllowJobLogBucketNotifications"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.s3_notifications.arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.gh_logs.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}
