resource "aws_kinesis_stream" "splunk_s3_runner_logs" {
  name             = "splunk-s3-runner-logs-stream-${var.aws_region}"
  retention_period = 24
  encryption_type  = "KMS"
  kms_key_id       = aws_kms_key.splunk_s3_runner_logs.arn
  stream_mode_details { stream_mode = "ON_DEMAND" }
  tags = var.tags
}
