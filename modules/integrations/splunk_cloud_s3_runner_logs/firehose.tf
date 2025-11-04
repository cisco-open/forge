############################################
# IAM for Firehose
############################################

resource "aws_iam_role" "firehose_role" {
  name = "github-runner-logs-firehose-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "firehose.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

resource "aws_iam_policy" "firehose_policy" {
  name        = "github-runner-logs-firehose-policy"
  description = "Permissions for Firehose to read Kinesis and write to Splunk + backup S3"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "KinesisRead"
        Effect   = "Allow"
        Action   = ["kinesis:GetShardIterator", "kinesis:GetRecords", "kinesis:DescribeStream"]
        Resource = aws_kinesis_stream.log_lines_stream.arn
      },
      {
        Sid    = "S3BackupWrite"
        Effect = "Allow"
        Action = ["s3:PutObject", "s3:GetBucketLocation", "s3:GetObject", "s3:ListBucket"]
        Resource = [
          aws_s3_bucket.firehose_backup.arn,
          "${aws_s3_bucket.firehose_backup.arn}/*"
        ]
      },
      {
        Sid      = "KMS"
        Effect   = "Allow"
        Action   = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
        Resource = aws_kms_key.log_lines_stream.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "firehose_attach" {
  role       = aws_iam_role.firehose_role.name
  policy_arn = aws_iam_policy.firehose_policy.arn
}

############################################
# Firehose Delivery Stream -> Splunk HEC
############################################

resource "aws_kinesis_firehose_delivery_stream" "splunk_firehose" {
  name        = "github-runner-logs-to-splunk"
  destination = "splunk"
  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.log_lines_stream.arn
    role_arn           = aws_iam_role.firehose_role.arn
  }
  splunk_configuration {
    hec_endpoint               = "https://${var.splunk_hec_host}:${var.splunk_hec_port}/services/collector/raw"
    hec_token                  = data.aws_secretsmanager_secret_version.secrets["splunk_cloud_hec_token_s3_integration"].secret_string
    hec_acknowledgment_timeout = 180
    retry_duration             = 300
    s3_backup_mode             = "FailedEventsOnly" # adjust if you want AllEvents
    s3_configuration {
      role_arn           = aws_iam_role.firehose_role.arn
      bucket_arn         = aws_s3_bucket.firehose_backup.arn
      buffering_interval = 60
      buffering_size     = 5
      compression_format = "GZIP"
    }
  }
  tags       = var.tags
  depends_on = [aws_iam_role_policy_attachment.firehose_attach]
}
