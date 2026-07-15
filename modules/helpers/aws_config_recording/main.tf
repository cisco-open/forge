locals {
  dedicated_host_resource_types = [
    "AWS::EC2::Host",
    "AWS::EC2::Instance",
  ]
}

resource "aws_iam_role" "config" {
  name               = var.iam_role_name
  assume_role_policy = data.aws_iam_policy_document.config_assume_role.json
  tags               = local.all_security_tags
}

resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_s3_bucket" "config_delivery" {
  bucket        = var.delivery_bucket_name
  force_destroy = var.force_destroy_delivery_bucket
  tags          = local.all_security_tags
}

resource "aws_s3_bucket_public_access_block" "config_delivery" {
  bucket = aws_s3_bucket.config_delivery.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "config_delivery" {
  bucket = aws_s3_bucket.config_delivery.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "config_delivery" {
  bucket = aws_s3_bucket.config_delivery.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "config_delivery" {
  bucket = aws_s3_bucket.config_delivery.id
  policy = data.aws_iam_policy_document.config_delivery_bucket.json
}

resource "aws_config_configuration_recorder" "dedicated_hosts" {
  name     = var.recorder_name
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported  = false
    resource_types = local.dedicated_host_resource_types

    recording_strategy {
      use_only = "INCLUSION_BY_RESOURCE_TYPES"
    }
  }

  recording_mode {
    recording_frequency = "CONTINUOUS"
  }

  depends_on = [aws_iam_role_policy_attachment.config]
}

resource "aws_config_delivery_channel" "dedicated_hosts" {
  name           = var.delivery_channel_name
  s3_bucket_name = aws_s3_bucket.config_delivery.bucket

  depends_on = [
    aws_config_configuration_recorder.dedicated_hosts,
    aws_s3_bucket_policy.config_delivery,
  ]
}

resource "aws_config_configuration_recorder_status" "dedicated_hosts" {
  name       = aws_config_configuration_recorder.dedicated_hosts.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.dedicated_hosts]
}
