locals {
  prefix_firehose = "splunk-s3-runner-logs-firehose"
}

resource "aws_iam_role" "firehose_role" {
  name = "${local.prefix_firehose}-role-${var.aws_region}"
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
  name        = "${local.prefix_firehose}-policy-${var.aws_region}"
  description = "Permissions for Firehose to read Kinesis and write to Splunk + backup S3"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "KinesisRead"
        Effect = "Allow"
        Action = [
          "kinesis:DescribeStream",
          "kinesis:GetShardIterator",
          "kinesis:GetRecords",
          "kinesis:ListShards"
        ]
        Resource = aws_kinesis_stream.splunk_s3_runner_logs.arn
      },
      {
        Sid    = "S3BackupWrite"
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.firehose_backup.arn,
          "${aws_s3_bucket.firehose_backup.arn}/*"
        ]
      },
      {
        Sid      = "KMS"
        Effect   = "Allow"
        Action   = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
        Resource = aws_kms_key.splunk_s3_runner_logs.arn
      },
      {
        Sid    = "LogsWrite"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents"
        ]
        Resource = [
          "${aws_cloudwatch_log_group.firehose_splunk.arn}",
          "${aws_cloudwatch_log_group.firehose_splunk.arn}:*"
        ]
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
  name        = "${local.prefix_firehose}-${var.aws_region}"
  destination = "splunk"
  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.splunk_s3_runner_logs.arn
    role_arn           = aws_iam_role.firehose_role.arn
  }
  splunk_configuration {
    hec_endpoint               = var.splunk_hec_endpoint
    hec_token                  = data.aws_secretsmanager_secret_version.secrets["splunk_cloud_hec_token_s3_integration"].secret_string
    hec_acknowledgment_timeout = 180
    retry_duration             = 300
    hec_endpoint_type          = "Event"
    s3_backup_mode             = "FailedEventsOnly"
    s3_configuration {
      role_arn           = aws_iam_role.firehose_role.arn
      bucket_arn         = aws_s3_bucket.firehose_backup.arn
      buffering_interval = 60
      buffering_size     = 5
      compression_format = "GZIP"
    }
    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.firehose_splunk.name
      log_stream_name = "delivery"
    }
  }
  tags = var.tags
}

# CloudWatch Log Group for Firehose delivery diagnostics
resource "aws_cloudwatch_log_group" "firehose_splunk" {
  name              = "/aws/kinesisfirehose/${local.prefix_firehose}-${var.aws_region}"
  retention_in_days = var.logging_retention_in_days
  kms_key_id        = aws_kms_key.splunk_s3_runner_logs.arn
  tags              = var.tags
}
