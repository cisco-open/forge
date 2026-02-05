locals {
  prefix_lambda = "splunk-s3-runner-logs"
}

module "splunk_s3_runner_logs_lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.1.2"

  function_name = "${local.prefix_lambda}-lambda-${var.aws_region}"
  handler       = "splunk_s3_runner_logs.lambda_handler"
  runtime       = "python3.12"
  timeout       = 900
  architectures = ["x86_64"]

  source_path = [{
    path = "${path.module}/lambda"
  }]

  logging_log_group                 = aws_cloudwatch_log_group.splunk_s3_runner_logs_lambda.name
  use_existing_cloudwatch_log_group = true

  trigger_on_package_timestamp = false

  environment_variables = {
    KINESIS_STREAM_NAME = aws_kinesis_stream.splunk_s3_runner_logs.name
    LOG_LEVEL           = var.log_level
  }

  attach_policy_json = true

  policy_json = data.aws_iam_policy_document.splunk_s3_runner_logs_lambda.json

  function_tags = var.tags
  role_tags     = var.tags
  tags          = var.tags

  depends_on = [aws_cloudwatch_log_group.splunk_s3_runner_logs_lambda]
}

data "aws_iam_policy_document" "splunk_s3_runner_logs_lambda" {

  statement {
    sid       = "S3Read"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:GetObjectVersion", "s3:GetObjectTagging"]
    resources = [for b in local.bucket_list : "arn:aws:s3:::${b.name}/*"]
  }

  statement {
    sid       = "KinesisWrite"
    effect    = "Allow"
    actions   = ["kinesis:PutRecords"]
    resources = [aws_kinesis_stream.splunk_s3_runner_logs.arn]
  }

  statement {
    sid       = "SQSPoll"
    effect    = "Allow"
    actions   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
    resources = [aws_sqs_queue.log_events_queue.arn]
  }

  statement {
    sid       = "Logs"
    effect    = "Allow"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["*"]
  }

  statement {
    sid       = "KMS"
    effect    = "Allow"
    actions   = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
    resources = [aws_kms_key.splunk_s3_runner_logs.arn]
  }

  statement {
    sid    = "KMSBuckets"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey"
    ]
    resources = [
      for b in local.bucket_list :
      b.kms
    ]
  }
}

resource "aws_cloudwatch_log_group" "splunk_s3_runner_logs_lambda" {
  name              = "/aws/lambda/${local.prefix_lambda}-lambda-${var.aws_region}"
  retention_in_days = var.logging_retention_in_days
  tags              = var.tags
  tags_all          = var.tags
}

resource "aws_lambda_event_source_mapping" "sqs_to_lambda" {
  event_source_arn                   = aws_sqs_queue.log_events_queue.arn
  function_name                      = module.splunk_s3_runner_logs_lambda.lambda_function_arn
  batch_size                         = 1
  maximum_batching_window_in_seconds = 0
  enabled                            = true
}
