locals {
  redrive_function_name = "${local.prefix_lambda}-redrive-${var.aws_region}"
}

module "splunk_s3_runner_logs_redrive_lambda" {
  #checkov:skip=CKV_TF_1:Module source uses Renovate-managed version tags; commit SHA pinning is an accepted policy tradeoff.
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.8.0"

  function_name = local.redrive_function_name
  handler       = "redrive_runner_logs.lambda_handler"
  runtime       = "python3.12"
  timeout       = 60
  architectures = ["x86_64"]

  source_path = [{
    path = "${path.module}/lambda/redrive_runner_logs"
  }]

  logging_log_group                 = aws_cloudwatch_log_group.splunk_s3_runner_logs_redrive.name
  use_existing_cloudwatch_log_group = true

  trigger_on_package_timestamp = false

  environment_variables = {
    DLQ_ARN   = aws_sqs_queue.log_events_dlq.arn
    LOG_LEVEL = var.log_level
  }

  attach_policy_json = true
  policy_json        = data.aws_iam_policy_document.splunk_s3_runner_logs_redrive.json

  function_tags = local.module_tags
  role_tags     = local.module_tags
  tags          = local.module_tags

  depends_on = [aws_cloudwatch_log_group.splunk_s3_runner_logs_redrive]
}

data "aws_iam_policy_document" "splunk_s3_runner_logs_redrive" {
  statement {
    sid    = "ReadAndRedriveDLQ"
    effect = "Allow"
    actions = [
      "sqs:StartMessageMoveTask",
      "sqs:ReceiveMessage",
      "sqs:GetQueueAttributes",
      "sqs:DeleteMessage",
    ]
    resources = [aws_sqs_queue.log_events_dlq.arn]
  }

  statement {
    sid       = "SendToSourceQueue"
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.log_events_queue.arn]
  }

  statement {
    sid    = "UseQueueKMSKey"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
    ]
    resources = [aws_kms_key.splunk_s3_runner_logs.arn]
  }
}

resource "aws_cloudwatch_log_group" "splunk_s3_runner_logs_redrive" {
  #checkov:skip=CKV_AWS_158:CloudWatch KMS encryption is deferred until this log delivery path is tested with customer-managed keys.
  #checkov:skip=CKV_AWS_338:CloudWatch retention is intentionally operator-defined; teams may keep short CloudWatch windows when exporting logs to Splunk or Loki.
  name              = "/aws/lambda/${local.redrive_function_name}"
  retention_in_days = var.logging_retention_in_days
  tags              = local.module_tags
  tags_all          = local.module_tags
}

resource "aws_cloudwatch_event_rule" "splunk_s3_runner_logs_redrive" {
  name                = local.redrive_function_name
  description         = "Redrive failed runner-log events every 10 minutes"
  schedule_expression = "cron(*/10 * * * ? *)"
  tags                = local.module_tags
  tags_all            = local.module_tags
}

resource "aws_cloudwatch_event_target" "splunk_s3_runner_logs_redrive" {
  rule = aws_cloudwatch_event_rule.splunk_s3_runner_logs_redrive.name
  arn  = module.splunk_s3_runner_logs_redrive_lambda.lambda_function_arn
}

resource "aws_lambda_permission" "splunk_s3_runner_logs_redrive" {
  action        = "lambda:InvokeFunction"
  function_name = module.splunk_s3_runner_logs_redrive_lambda.lambda_function_name
  principal     = "events.amazonaws.com"
  statement_id  = "AllowExecutionFromEventBridge"
  source_arn    = aws_cloudwatch_event_rule.splunk_s3_runner_logs_redrive.arn
}
