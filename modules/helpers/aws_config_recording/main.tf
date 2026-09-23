resource "aws_iam_role" "config" {
  name               = local.iam_role_name
  assume_role_policy = data.aws_iam_policy_document.config_assume_role.json
  tags               = local.all_security_tags
}

resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_s3_bucket" "config_delivery" {
  count = local.create_delivery_resources ? 1 : 0

  #checkov:skip=CKV_AWS_145:SSE-S3 is compatible with AWS Config delivery and avoids a KMS key dependency for the archive.
  #checkov:skip=CKV_AWS_144:Each recorder writes to a regional bucket; cross-region replication is outside this module's archival contract.
  #checkov:skip=CKV_AWS_18:CloudTrail provides control-plane audit records; a separate access-log bucket is not part of this helper.
  bucket        = local.delivery_bucket_name
  force_destroy = false
  tags          = local.all_security_tags
}

resource "aws_s3_bucket_ownership_controls" "config_delivery" {
  count = local.create_delivery_resources ? 1 : 0

  # AWS Config delivers objects with the bucket-owner-full-control ACL.
  #checkov:skip=CKV2_AWS_65:BucketOwnerPreferred preserves the ACL required by the AWS Config delivery contract.
  bucket = aws_s3_bucket.config_delivery[0].id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_versioning" "config_delivery" {
  count = local.create_delivery_resources ? 1 : 0

  bucket = aws_s3_bucket.config_delivery[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "config_delivery" {
  count = local.create_delivery_resources ? 1 : 0

  bucket = aws_s3_bucket.config_delivery[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "config_delivery" {
  count = local.create_delivery_resources ? 1 : 0

  bucket                  = aws_s3_bucket.config_delivery[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
  skip_destroy            = true
}

resource "aws_s3_bucket_lifecycle_configuration" "config_delivery" {
  count = local.create_delivery_resources ? 1 : 0

  bucket = aws_s3_bucket.config_delivery[0].id

  rule {
    id     = "abort-incomplete-config-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.config_delivery]
}

resource "aws_s3_bucket_policy" "config_delivery" {
  count = local.create_delivery_resources ? 1 : 0

  bucket = aws_s3_bucket.config_delivery[0].id
  policy = data.aws_iam_policy_document.config_delivery_bucket[0].json

  depends_on = [
    aws_s3_bucket_ownership_controls.config_delivery,
    aws_s3_bucket_public_access_block.config_delivery,
    aws_s3_bucket_server_side_encryption_configuration.config_delivery,
    aws_s3_bucket_versioning.config_delivery,
  ]
}

resource "aws_sqs_queue" "config_events_dlq" {
  count = local.create_delivery_resources ? 1 : 0

  name                      = local.config_events_dlq_name
  message_retention_seconds = 1209600 # 14 days
  sqs_managed_sse_enabled   = true
  tags                      = local.all_security_tags
}

resource "aws_sqs_queue" "config_events" {
  count = local.create_delivery_resources ? 1 : 0

  name                       = local.config_events_queue_name
  message_retention_seconds  = 1209600 # 14 days
  visibility_timeout_seconds = 300
  sqs_managed_sse_enabled    = true
  tags                       = local.all_security_tags

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.config_events_dlq[0].arn
    maxReceiveCount     = 5
  })
}

resource "aws_sqs_queue_policy" "config_events" {
  count = local.create_delivery_resources ? 1 : 0

  queue_url = aws_sqs_queue.config_events[0].url
  policy    = data.aws_iam_policy_document.config_events[0].json
}

# S3 notification configuration is atomic. This resource must remain the only
# Terraform owner of notifications for the managed delivery bucket.
resource "aws_s3_bucket_notification" "config_events" {
  count = local.create_delivery_resources ? 1 : 0

  bucket = aws_s3_bucket.config_delivery[0].id

  queue {
    id            = "aws-config-json-gzip"
    queue_arn     = aws_sqs_queue.config_events[0].arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "AWSLogs/${data.aws_caller_identity.current.account_id}/Config/${var.aws_region}/"
    filter_suffix = ".json.gz"
  }

  depends_on = [aws_sqs_queue_policy.config_events]
}

resource "aws_config_configuration_recorder" "this" {
  #checkov:skip=CKV2_AWS_45:Selective recording is intentional; callers supply recorded_resource_types.
  #checkov:skip=CKV2_AWS_48:Global resources are recorded only when explicitly selected by the caller.
  name     = var.recorder_name
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported  = false
    resource_types = sort(tolist(var.recorded_resource_types))

    recording_strategy {
      use_only = "INCLUSION_BY_RESOURCE_TYPES"
    }
  }

  recording_mode {
    recording_frequency = "CONTINUOUS"
  }

  depends_on = [aws_iam_role_policy_attachment.config]
}

resource "aws_config_delivery_channel" "this" {
  name           = var.delivery_channel_name
  s3_bucket_name = local.delivery_bucket_name

  depends_on = [
    aws_config_configuration_recorder.this,
    aws_s3_bucket_lifecycle_configuration.config_delivery,
    aws_s3_bucket_notification.config_events,
    aws_s3_bucket_policy.config_delivery,
  ]
}

resource "aws_config_configuration_recorder_status" "this" {
  name       = aws_config_configuration_recorder.this.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.this]
}
