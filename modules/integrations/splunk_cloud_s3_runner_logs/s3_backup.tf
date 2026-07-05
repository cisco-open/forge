resource "aws_s3_bucket" "firehose_backup" {
  #checkov:skip=CKV_AWS_144:Cross-region replication is intentionally omitted because it is not needed for this bucket's use case.
  #checkov:skip=CKV_AWS_18:S3 server access logging is an accepted policy exception for this Forge storage bucket; audit needs are handled outside S3 access logs.
  #checkov:skip=CKV2_AWS_61:Backup bucket lifecycle expiration is deferred until failed-delivery retention requirements are validated.
  #checkov:skip=CKV2_AWS_62:Backup bucket is only a failed-delivery target and has no event-driven consumer.
  bucket = "splunk-s3-runner-logs-failed-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
  tags   = var.tags
}

resource "aws_s3_bucket_ownership_controls" "firehose_backup" {
  #checkov:skip=CKV2_AWS_65:BucketOwnerEnforced ACL disabling is deferred until Firehose failed-delivery object ownership is regression-tested.
  bucket = aws_s3_bucket.firehose_backup.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_versioning" "firehose_backup" {
  bucket = aws_s3_bucket.firehose_backup.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "firehose_backup" {
  bucket = aws_s3_bucket.firehose_backup.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.splunk_s3_runner_logs.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "firehose_backup" {
  bucket                  = aws_s3_bucket.firehose_backup.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
