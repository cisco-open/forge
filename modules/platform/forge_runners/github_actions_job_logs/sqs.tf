resource "aws_sqs_queue" "jobs_dlq" {
  name                       = "${var.prefix}-gha-job-logs-dead-letter"
  message_retention_seconds  = 1209600 # 14 days
  visibility_timeout_seconds = 30
  tags                       = var.tags
  tags_all                   = var.tags
}

resource "aws_sqs_queue" "jobs" {
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
