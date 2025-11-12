locals {
  resource_name_archiver = "${var.prefix}-job-log-archiver"
  github_api             = var.ghes_url == "" ? "https://api.github.com" : "https://api.${replace(var.ghes_url, "https://", "")}"
}

module "job_log_archiver" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.1.2"

  function_name = local.resource_name_archiver
  handler       = "job_log_archiver.lambda_handler"
  runtime       = "python3.12"
  timeout       = 900
  architectures = ["x86_64"]

  source_path = [{
    path = "${path.module}/lambda/job_log_archiver"
  }]

  layers = [
    "arn:aws:lambda:${data.aws_region.current.region}:770693421928:layer:Klayers-p312-cryptography:17",
    "arn:aws:lambda:${data.aws_region.current.region}:770693421928:layer:Klayers-p312-requests:17",
    "arn:aws:lambda:${data.aws_region.current.region}:770693421928:layer:Klayers-p312-PyJWT:1",
  ]

  logging_log_group                 = aws_cloudwatch_log_group.job_log_archiver.name
  use_existing_cloudwatch_log_group = true

  trigger_on_package_timestamp = false

  environment_variables = {
    GITHUB_API                  = local.github_api
    SECRET_NAME_APP_ID          = local.secrets["github_actions_runners_app_id"].name
    SECRET_NAME_PRIVATE_KEY     = local.secrets["github_actions_runners_app_key"].name
    SECRET_NAME_INSTALLATION_ID = local.secrets["github_actions_runners_app_installation_id"].name
    BUCKET_NAME                 = aws_s3_bucket.gh_logs.id
    KMS_KEY_ARN                 = aws_kms_key.gh_logs.arn
    LOG_LEVEL                   = var.log_level
  }

  attach_policy_json = true

  policy_json = data.aws_iam_policy_document.job_log_archiver.json

  function_tags = var.tags
  role_tags     = var.tags
  tags          = var.tags

  depends_on = [aws_cloudwatch_log_group.job_log_archiver]
}

data "aws_iam_policy_document" "job_log_archiver" {
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts",
      "s3:ListBucket",
      "s3:GetObject",
      "s3:PutObjectTagging",
      "s3:GetObjectTagging"
    ]
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.gh_logs.id}",
      "arn:aws:s3:::${aws_s3_bucket.gh_logs.id}/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey",
      "kms:GenerateDataKeyWithoutPlaintext",
      "kms:DescribeKey"
    ]
    resources = [aws_kms_key.gh_logs.arn]
  }

  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = [
      data.aws_secretsmanager_secret_version.secrets["github_actions_runners_app_key"].arn,
      data.aws_secretsmanager_secret_version.secrets["github_actions_runners_app_id"].arn,
      data.aws_secretsmanager_secret_version.secrets["github_actions_runners_app_installation_id"].arn,
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes"
    ]
    resources = [aws_sqs_queue.jobs.arn]
  }
}

resource "aws_cloudwatch_log_group" "job_log_archiver" {
  name              = "/aws/lambda/${local.resource_name_archiver}"
  retention_in_days = var.logging_retention_in_days
  tags              = var.tags
  tags_all          = var.tags
}

resource "aws_lambda_event_source_mapping" "job_log_archiver" {
  event_source_arn = aws_sqs_queue.jobs.arn
  function_name    = module.job_log_archiver.lambda_function_name
  batch_size       = 1
}

resource "aws_lambda_permission" "scale_runners_lambda" {
  statement_id  = "AllowExecutionFromSQS"
  action        = "lambda:InvokeFunction"
  function_name = module.job_log_archiver.lambda_function_name
  principal     = "sqs.amazonaws.com"
  source_arn    = aws_sqs_queue.jobs.arn
}
