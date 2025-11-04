resource "aws_kms_key" "log_lines_stream" {
  description             = "KMS key for GitHub logs ingestion pipeline"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = var.tags
}

resource "aws_kms_alias" "log_lines_stream" {
  name          = "alias/github-runner-logs-lines"
  target_key_id = aws_kms_key.log_lines_stream.arn
}

resource "aws_kinesis_stream" "log_lines_stream" {
  name             = "github-runner-logs-lines"
  retention_period = 24
  encryption_type  = "KMS"
  kms_key_id       = aws_kms_key.log_lines_stream.arn
  stream_mode_details { stream_mode = "ON_DEMAND" }
  tags = var.tags
}

resource "aws_cloudwatch_log_group" "log_lines_stream" {
  name              = "/aws/kinesis/${aws_kinesis_stream.log_lines_stream.name}"
  retention_in_days = var.logging_retention_in_days
  kms_key_id        = aws_kms_key.log_lines_stream.arn
  tags              = var.tags
}
