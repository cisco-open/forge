resource "aws_s3_bucket" "gh_logs" {
  bucket   = "${var.prefix}-forge-gh-logs-${data.aws_caller_identity.current.account_id}"
  tags     = var.tags
  tags_all = var.tags
}

resource "aws_s3_bucket_ownership_controls" "gh_logs" {
  bucket = aws_s3_bucket.gh_logs.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_versioning" "gh_logs" {
  bucket = aws_s3_bucket.gh_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_kms_key" "gh_logs" {
  description             = "KMS key for GitHub workflow/job logs bucket ${aws_s3_bucket.gh_logs.id}"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "EnableRootAccountAdminAccess",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action = [
          "kms:*"
        ],
        Resource = "*"
      },
      {
        Sid    = "AllowInternalRoleDecrypt",
        Effect = "Allow",
        Principal = {
          AWS = aws_iam_role.internal_s3_reader.arn
        },
        Action   = ["kms:Decrypt", "kms:DescribeKey", "kms:GenerateDataKey*"],
        Resource = "*"
      },
      {
        Sid       = "AllowLambdaArchiverUse",
        Effect    = "Allow",
        Principal = { AWS = module.job_log_archiver.lambda_role_arn },
        Action    = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey*", "kms:DescribeKey"],
        Resource  = "*"
      }
    ]
  })
  tags     = var.tags
  tags_all = var.tags
}

resource "aws_kms_alias" "gh_logs" {
  name          = "alias/${var.prefix}-gh-logs-key"
  target_key_id = aws_kms_key.gh_logs.id
}

resource "aws_s3_bucket_server_side_encryption_configuration" "gh_logs" {
  bucket = aws_s3_bucket.gh_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.gh_logs.arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "gh_logs" {
  bucket                  = aws_s3_bucket.gh_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


resource "aws_s3_bucket_lifecycle_configuration" "gh_logs" {
  bucket = aws_s3_bucket.gh_logs.id
  rule {
    id     = "expire-infrequent-mpu-markers"
    status = "Enabled"
    abort_incomplete_multipart_upload { days_after_initiation = 7 }
  }
}

resource "aws_s3_bucket_policy" "gh_logs_read" {
  bucket = aws_s3_bucket.gh_logs.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowInternalRoleRead"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.internal_s3_reader.arn
        }
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.gh_logs.arn,
          "${aws_s3_bucket.gh_logs.arn}/*"
        ]
      }
    ]
  })
}
