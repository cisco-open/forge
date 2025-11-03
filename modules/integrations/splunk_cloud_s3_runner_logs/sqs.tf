resource "aws_sqs_queue" "log_events_queue" {
  name                       = "github-runner-logs-s3-events"
  visibility_timeout_seconds = 180
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

# Allow each source bucket to send notifications to SQS
resource "aws_sqs_queue_policy" "allow_s3" {
  queue_url = aws_sqs_queue.log_events_queue.url
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [for b in var.s3_bucket_names : {
      Sid       = "AllowS3SendMessage-${b}"
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.log_events_queue.arn
      Condition = {
        ArnEquals = {
          "aws:SourceArn" = "arn:aws:s3:::${b}"
        }
      }
    }]
  })
}

resource "aws_s3_bucket_notification" "to_sqs" {
  for_each = toset(var.s3_bucket_names)
  bucket   = each.key
  queue {
    queue_arn     = aws_sqs_queue.log_events_queue.arn
    events        = ["s3:ObjectCreated:Put", "s3:ObjectCreated:CompleteMultipartUpload"]
    filter_suffix = var.filter_suffix
  }
  depends_on = [aws_sqs_queue_policy.allow_s3]
}
