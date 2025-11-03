resource "aws_kms_key" "log_lines_stream" {
  description             = "KMS key for GitHub logs ingestion pipeline"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = var.tags
}

resource "aws_kms_alias" "log_lines_stream" {
  name          = "alias/github-runner-logs-lines"
  target_key_id = aws_kms_key.log_lines_stream.id
}

resource "aws_kinesis_stream" "log_lines_stream" {
  name             = "github-runner-logs-lines"
  shard_count      = 1
  retention_period = 24
  encryption_type  = "KMS"
  kms_key_id       = aws_kms_key.log_lines_stream.id
  stream_mode_details { stream_mode = "ON_DEMAND" }
  tags = var.tags
}
