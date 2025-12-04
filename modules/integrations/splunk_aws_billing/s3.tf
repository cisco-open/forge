resource "aws_s3_bucket" "aws_billing_report" {
  bucket = "${data.aws_caller_identity.current.account_id}-aws-billing-report"
  tags   = local.all_security_tags
}

resource "aws_s3_bucket_ownership_controls" "aws_billing_report" {
  bucket = aws_s3_bucket.aws_billing_report.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "aws_billing_report" {
  bucket = aws_s3_bucket.aws_billing_report.id

  rule {
    id     = "30d-cleanup-all"
    status = "Enabled"

    filter {}

    expiration {
      days = 30
    }
  }
}

resource "aws_s3_bucket_versioning" "aws_billing_report" {
  bucket = aws_s3_bucket.aws_billing_report.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "aws_billing_report_settings" {
  bucket = aws_s3_bucket.aws_billing_report.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "aws_billing_report" {
  bucket                  = aws_s3_bucket.aws_billing_report.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  skip_destroy = true
}

data "aws_iam_policy_document" "cur_bucket_policy" {
  statement {
    sid    = "AWSBillingPermissionsCheck"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["billingreports.amazonaws.com"]
    }

    actions = ["s3:GetBucketAcl"]

    resources = [
      aws_s3_bucket.aws_billing_report.arn
    ]
  }

  statement {
    sid    = "AWSBillingWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["billingreports.amazonaws.com"]
    }

    actions = ["s3:PutObject"]

    resources = [
      "${aws_s3_bucket.aws_billing_report.arn}/*"
    ]
  }

  statement {
    sid    = "EnableAWSDataExportsToWriteToS3AndCheckPolicy"
    effect = "Allow"

    principals {
      type = "Service"
      identifiers = [
        "billingreports.amazonaws.com",
        "bcm-data-exports.amazonaws.com"
      ]
    }

    actions = [
      "s3:PutObject",
      "s3:GetBucketPolicy"
    ]

    resources = [
      aws_s3_bucket.aws_billing_report.arn,
      "${aws_s3_bucket.aws_billing_report.arn}/*"
    ]

    condition {
      test     = "StringLike"
      variable = "aws:SourceArn"
      values = [
        "arn:aws:cur:us-east-1:${data.aws_caller_identity.current.account_id}:definition/*",
        "arn:aws:bcm-data-exports:us-east-1:${data.aws_caller_identity.current.account_id}:export/*"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_s3_bucket_policy" "cur_bucket_policy" {
  bucket = aws_s3_bucket.aws_billing_report.id
  policy = data.aws_iam_policy_document.cur_bucket_policy.json
}

resource "aws_s3_bucket_notification" "cur_notification" {
  bucket = aws_s3_bucket.aws_billing_report.id

  lambda_function {
    lambda_function_arn = module.cur_per_service.lambda_function_arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "cur-per-service/aws-billing-report-per-service/data/"
  }

  lambda_function {
    lambda_function_arn = module.cur_per_resource.lambda_function_arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "cur-per-resource/aws-billing-report-per-resource/data/"
  }

  lambda_function {
    lambda_function_arn = module.cur_per_resource_process.lambda_function_arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "tmp/cur-per-resource/"
  }

  depends_on = [
    aws_lambda_permission.cur_per_resource_process,
    aws_lambda_permission.cur_per_service,
    aws_lambda_permission.cur_per_resource
  ]
}
