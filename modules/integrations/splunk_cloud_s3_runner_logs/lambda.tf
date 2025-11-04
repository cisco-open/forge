
module "s3_to_kinesis_lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.1.0"

  function_name = "github-runner-logs-s3-to-kinesis-lambda"
  handler       = "s3_to_kinesis.lambda_handler"
  runtime       = "python3.12"
  timeout       = 900
  architectures = ["x86_64"]

  source_path = [{
    path = "${path.module}/lambda"
  }]

  logging_log_group                 = aws_cloudwatch_log_group.s3_to_kinesis_lambda.name
  use_existing_cloudwatch_log_group = true

  trigger_on_package_timestamp = false

  environment_variables = {
    KINESIS_STREAM_NAME = aws_kinesis_stream.log_lines_stream.name
    SOURCETYPE          = var.splunk_hec_sourcetype
    LOG_LEVEL           = var.log_level
  }

  attach_policy_json = true

  policy_json = data.aws_iam_policy_document.s3_to_kinesis_lambda.json

  function_tags = var.tags
  role_tags     = var.tags
  tags          = var.tags

  depends_on = [aws_cloudwatch_log_group.s3_to_kinesis_lambda]
}

data "aws_iam_policy_document" "s3_to_kinesis_lambda" {

  statement {
    sid       = "S3Read"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:GetObjectVersion"]
    resources = [for b in local.bucket_list : "arn:aws:s3:::${b.name}/*"]
  }

  statement {
    sid       = "KinesisWrite"
    effect    = "Allow"
    actions   = ["kinesis:PutRecords"]
    resources = [aws_kinesis_stream.log_lines_stream.arn]
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
    resources = [aws_kms_key.log_lines_stream.arn]
  }

}

resource "aws_cloudwatch_log_group" "s3_to_kinesis_lambda" {
  name              = "/aws/lambda/github-runner-logs-s3-to-kinesis-lambda"
  retention_in_days = var.logging_retention_in_days
  tags              = var.tags
  tags_all          = var.tags
}

resource "aws_lambda_event_source_mapping" "sqs_to_lambda" {
  event_source_arn                   = aws_sqs_queue.log_events_queue.arn
  function_name                      = module.s3_to_kinesis_lambda.lambda_function_arn
  batch_size                         = 1
  maximum_batching_window_in_seconds = 0
  enabled                            = true
}
