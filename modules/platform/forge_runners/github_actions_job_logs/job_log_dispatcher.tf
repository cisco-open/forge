locals {
  resource_name_dispatcher = "${var.prefix}-job-log-dispatcher"
}

module "job_log_dispatcher" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.1.0"

  function_name = local.resource_name_dispatcher
  handler       = "job_log_dispatcher.lambda_handler"
  runtime       = "python3.12"
  timeout       = 900
  architectures = ["x86_64"]

  source_path = [{
    path = "${path.module}/lambda/job_log_dispatcher"
  }]

  logging_log_group                 = aws_cloudwatch_log_group.job_log_dispatcher.name
  use_existing_cloudwatch_log_group = true

  trigger_on_package_timestamp = false


  environment_variables = {
    QUEUE_URL = aws_sqs_queue.jobs.url
  }

  attach_policy_json = true

  policy_json = data.aws_iam_policy_document.job_log_dispatcher.json

  function_tags = var.tags
  role_tags     = var.tags
  tags          = var.tags

  depends_on = [aws_cloudwatch_log_group.job_log_dispatcher]
}

data "aws_iam_policy_document" "job_log_dispatcher" {
  statement {
    effect  = "Allow"
    actions = ["sqs:SendMessage", "sqs:SendMessageBatch"]
    resources = [
      aws_sqs_queue.jobs.arn
    ]
  }
}

resource "aws_cloudwatch_log_group" "job_log_dispatcher" {
  name              = "/aws/lambda/${local.resource_name_dispatcher}"
  retention_in_days = var.logging_retention_in_days
  tags              = var.tags
  tags_all          = var.tags
}

resource "aws_lambda_permission" "job_log_dispatcher" {
  action        = "lambda:InvokeFunction"
  function_name = local.resource_name_dispatcher
  principal     = "events.amazonaws.com"
  statement_id  = "AllowExecutionFromCloudWatch"
  source_arn    = aws_cloudwatch_event_rule.job_log_dispatcher.arn

  depends_on = [module.job_log_dispatcher]
}

resource "aws_cloudwatch_event_rule" "job_log_dispatcher" {
  name           = local.resource_name_dispatcher
  description    = "Workflow job event rule to enqueue archived job logs."
  event_bus_name = var.event_bus_name

  tags     = var.tags
  tags_all = var.tags

  event_pattern = <<EOF
{
  "detail-type": ["workflow_job"],
  "detail": {
    "action": ["completed"]
  }
}
EOF
}

resource "aws_cloudwatch_event_target" "job_log_dispatcher" {
  arn            = module.job_log_dispatcher.lambda_function_arn
  rule           = aws_cloudwatch_event_rule.job_log_dispatcher.name
  event_bus_name = var.event_bus_name
}
