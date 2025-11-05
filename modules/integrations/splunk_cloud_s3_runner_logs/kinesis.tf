resource "aws_kinesis_stream" "log_lines_stream" {
  name             = "github-runner-logs-lines-${var.aws_region}"
  retention_period = 24
  encryption_type  = "KMS"
  kms_key_id       = aws_kms_key.log_lines_stream.arn
  stream_mode_details { stream_mode = "ON_DEMAND" }
  tags = var.tags
}
