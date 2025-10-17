resource "aws_iam_role" "internal_s3_reader" {
  name = "${var.prefix}-s3-reader-role"

  assume_role_policy = data.aws_iam_policy_document.internal_s3_reader_assume_role.json

  tags     = var.tags
  tags_all = var.tags
}

data "aws_iam_policy_document" "internal_s3_reader_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type = "AWS"
      identifiers = concat(
        ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"],
        var.shared_role_arns
      )
    }
    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

data "aws_iam_policy_document" "internal_s3_reader_policy_doc" {
  statement {
    sid    = "S3ReadAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.gh_logs.arn,
      "${aws_s3_bucket.gh_logs.arn}/*"
    ]
  }

  statement {
    sid    = "KMSDecryptAccess"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:GenerateDataKey*"
    ]
    resources = [
      aws_kms_key.gh_logs.arn
    ]
  }
}

resource "aws_iam_policy" "internal_s3_reader_policy" {
  name   = "InternalS3ReaderPolicy"
  policy = data.aws_iam_policy_document.internal_s3_reader_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "attach_internal_s3_reader" {
  role       = aws_iam_role.internal_s3_reader.name
  policy_arn = aws_iam_policy.internal_s3_reader_policy.arn
}
