mock_provider "aws" {}

override_data {
  target = data.aws_caller_identity.current
  values = {
    account_id = "123456789012"
    arn        = "arn:aws:iam::123456789012:user/test"
    user_id    = "test"
  }
}

override_resource {
  target = aws_s3_bucket.s3_long_term
  values = {
    id  = "123456789012-long-term-storage"
    arn = "arn:aws:s3:::123456789012-long-term-storage"
  }
}

override_resource {
  target = aws_s3_bucket.s3_short_term
  values = {
    id  = "123456789012-short-term-storage"
    arn = "arn:aws:s3:::123456789012-short-term-storage"
  }
}

variables {
  aws_profile = "test"
  aws_region  = "us-east-1"
  default_tags = {
    Product = "Forge"
  }
  tags = {
    Env = "test"
  }
}

run "storage_buckets_contract" {
  command = plan

  assert {
    condition = (
      aws_s3_bucket.s3_long_term.bucket == "123456789012-long-term-storage"
      && aws_s3_bucket.s3_long_term.tags.Product == "Forge"
      && aws_s3_bucket.s3_long_term.tags.Env == "test"
      && aws_s3_bucket_versioning.s3_long_term.versioning_configuration[0].status == "Enabled"
      && one(one(aws_s3_bucket_server_side_encryption_configuration.s3_long_term.rule).apply_server_side_encryption_by_default).sse_algorithm == "AES256"
      && aws_s3_bucket_public_access_block.s3_long_term.block_public_acls == true
      && aws_s3_bucket_public_access_block.s3_long_term.block_public_policy == true
      && aws_s3_bucket_public_access_block.s3_long_term.ignore_public_acls == true
      && aws_s3_bucket_public_access_block.s3_long_term.restrict_public_buckets == true
      && aws_s3_bucket_public_access_block.s3_long_term.skip_destroy == true
    )
    error_message = "Storage helper must keep long-term bucket naming, tags, versioning, AES256 encryption, and public access block settings."
  }

  assert {
    condition = (
      aws_s3_bucket.s3_short_term.bucket == "123456789012-short-term-storage"
      && aws_s3_bucket.s3_short_term.tags.Product == "Forge"
      && aws_s3_bucket.s3_short_term.tags.Env == "test"
      && aws_s3_bucket_lifecycle_configuration.s3_short_term.rule[0].id == "30d-cleanup-all"
      && aws_s3_bucket_lifecycle_configuration.s3_short_term.rule[0].expiration[0].days == 30
      && aws_s3_bucket_lifecycle_configuration.s3_short_term.rule[0].abort_incomplete_multipart_upload[0].days_after_initiation == 7
      && aws_s3_bucket_lifecycle_configuration.s3_short_term.rule[0].status == "Enabled"
      && aws_s3_bucket_versioning.s3_short_term.versioning_configuration[0].status == "Enabled"
      && one(one(aws_s3_bucket_server_side_encryption_configuration.s3_short_term_settings.rule).apply_server_side_encryption_by_default).sse_algorithm == "AES256"
      && aws_s3_bucket_public_access_block.s3_short_term.skip_destroy == true
    )
    error_message = "Storage helper must keep short-term bucket naming, tags, lifecycle cleanup, versioning, AES256 encryption, and public access block settings."
  }

  assert {
    condition = (
      output.s3_long_term_settings.path == "123456789012-long-term-storage/cicd_artifacts"
      && output.s3_long_term_settings.arn == "arn:aws:s3:::123456789012-long-term-storage"
      && output.s3_long_term_settings.suffix == "/cicd_artifacts"
      && output.s3_short_term_settings.path == "123456789012-short-term-storage/cicd_artifacts"
      && output.s3_short_term_settings.arn == "arn:aws:s3:::123456789012-short-term-storage"
      && output.s3_short_term_settings.suffix == "/cicd_artifacts"
    )
    error_message = "Storage helper must expose S3 artifact path, ARN, and suffix outputs."
  }
}
