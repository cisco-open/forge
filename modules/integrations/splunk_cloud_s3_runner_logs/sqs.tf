resource "aws_sqs_queue" "log_events_queue" {
  name                       = "github-runner-logs-s3-events"
  visibility_timeout_seconds = 900
  message_retention_seconds  = 86400
  kms_master_key_id          = aws_kms_key.log_lines_stream.arn
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.log_events_dlq.arn
    maxReceiveCount     = 2
  })
  tags = var.tags
}

resource "aws_sqs_queue" "log_events_dlq" {
  name                      = "github-runner-logs-s3-events-dlq"
  message_retention_seconds = 1209600 # 14 days
  kms_master_key_id         = aws_kms_key.log_lines_stream.arn
  tags                      = merge(var.tags, { Purpose = "dlq" })
}

resource "aws_sqs_queue_policy" "allow_s3" {
  queue_url = aws_sqs_queue.log_events_queue.url
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowForgeLogBucketsWildcard"
        Effect    = "Allow"
        Principal = { Service = "s3.amazonaws.com" }
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.log_events_queue.arn
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:s3:::*forge-gh-logs-${data.aws_caller_identity.current.account_id}"
          }
        }
      }
    ]
  })
}
