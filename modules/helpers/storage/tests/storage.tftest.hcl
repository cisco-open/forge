mock_provider "aws" {}

override_data {
  target = data.aws_caller_identity.current
  values = {
    account_id = "123456789012"
    arn        = "arn:aws:iam::123456789012:user/test"
    user_id    = "test"
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

run "storage_bucket_contract" {
  assert {
    condition = (
      aws_s3_bucket.s3_long_term.bucket == "123456789012-long-term-storage"
      && aws_s3_bucket.s3_short_term.bucket == "123456789012-short-term-storage"
    )
    error_message = "Storage helper bucket names must remain account-scoped and purpose-specific."
  }

  assert {
    condition = (
      aws_s3_bucket_versioning.s3_long_term.versioning_configuration[0].status == "Enabled"
      && aws_s3_bucket_versioning.s3_short_term.versioning_configuration[0].status == "Enabled"
    )
    error_message = "Storage helper buckets must keep versioning enabled."
  }

  assert {
    condition = (
      one(one(aws_s3_bucket_server_side_encryption_configuration.s3_long_term.rule).apply_server_side_encryption_by_default).sse_algorithm == "AES256"
      && one(one(aws_s3_bucket_server_side_encryption_configuration.s3_short_term_settings.rule).apply_server_side_encryption_by_default).sse_algorithm == "AES256"
    )
    error_message = "Storage helper buckets must keep default AES256 server-side encryption."
  }

  assert {
    condition = (
      aws_s3_bucket_public_access_block.s3_long_term.block_public_acls
      && aws_s3_bucket_public_access_block.s3_long_term.block_public_policy
      && aws_s3_bucket_public_access_block.s3_long_term.ignore_public_acls
      && aws_s3_bucket_public_access_block.s3_long_term.restrict_public_buckets
      && aws_s3_bucket_public_access_block.s3_short_term.block_public_acls
      && aws_s3_bucket_public_access_block.s3_short_term.block_public_policy
      && aws_s3_bucket_public_access_block.s3_short_term.ignore_public_acls
      && aws_s3_bucket_public_access_block.s3_short_term.restrict_public_buckets
    )
    error_message = "Storage helper buckets must keep all public access block settings enabled."
  }

  assert {
    condition = (
      aws_s3_bucket_lifecycle_configuration.s3_short_term.rule[0].id == "30d-cleanup-all"
      && aws_s3_bucket_lifecycle_configuration.s3_short_term.rule[0].expiration[0].days == 30
      && aws_s3_bucket_lifecycle_configuration.s3_short_term.rule[0].abort_incomplete_multipart_upload[0].days_after_initiation == 7
      && aws_s3_bucket_lifecycle_configuration.s3_short_term.rule[0].status == "Enabled"
    )
    error_message = "Short-term storage must keep 30 day object cleanup and 7 day incomplete multipart cleanup enabled."
  }
}
