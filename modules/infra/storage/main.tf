# Define sub-modules and other significant settings/resources/etc. here.
# Long-term storage (i.e. release builds and SBOMs we need to retain long-term
# for stability and auditing purposes).
resource "aws_s3_bucket" "s3_long_term" {
  bucket = "${data.aws_caller_identity.current.account_id}-long-term-storage"
  tags   = local.all_security_tags
}

# Ownership controls.
resource "aws_s3_bucket_ownership_controls" "s3_long_term" {
  bucket = aws_s3_bucket.s3_long_term.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Enable versioning of artifacts.
resource "aws_s3_bucket_versioning" "s3_long_term" {
  bucket = aws_s3_bucket.s3_long_term.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Bucket encryption settings.
resource "aws_s3_bucket_server_side_encryption_configuration" "s3_long_term" {
  bucket = aws_s3_bucket.s3_long_term.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Lock down the bucket.
resource "aws_s3_bucket_public_access_block" "s3_long_term" {
  bucket                  = aws_s3_bucket.s3_long_term.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  skip_destroy = true
}

# Short-term storage (i.e. temporary/feature-branch builds, core dumps, and
# other artifacts we aren't obligated to retain long-term).
resource "aws_s3_bucket" "s3_short_term" {
  bucket = "${data.aws_caller_identity.current.account_id}-short-term-storage"
  tags   = local.all_security_tags
}

# Ownership controls.
resource "aws_s3_bucket_ownership_controls" "s3_short_term" {
  bucket = aws_s3_bucket.s3_short_term.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Enable lifecycling.
resource "aws_s3_bucket_lifecycle_configuration" "s3_short_term" {
  bucket = aws_s3_bucket.s3_short_term.id

  rule {
    id = "30d-cleanup-all"
    expiration {
      days = 30
    }
    status = "Enabled"
  }
}

# Enable versioning of artifacts.
resource "aws_s3_bucket_versioning" "s3_short_term" {
  bucket = aws_s3_bucket.s3_short_term.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Bucket encryption settings.
resource "aws_s3_bucket_server_side_encryption_configuration" "s3_short_term_settings" {
  bucket = aws_s3_bucket.s3_short_term.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Lock down the bucket.
resource "aws_s3_bucket_public_access_block" "s3_short_term" {
  bucket                  = aws_s3_bucket.s3_short_term.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  skip_destroy = true
}
