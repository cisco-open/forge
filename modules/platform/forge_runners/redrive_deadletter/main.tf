module "redrive_deadletter_lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.1.2"

  function_name = "${var.prefix}-redrive-deadletter"
  handler       = "redrive_deadletter.lambda_handler"
  runtime       = "python3.12"
  timeout       = 900
  architectures = ["x86_64"]

  source_path = [{
    path = "${path.module}/lambda"
  }]

  logging_log_group                 = aws_cloudwatch_log_group.redrive_deadletter_lambda.name
  use_existing_cloudwatch_log_group = true

  trigger_on_package_timestamp = false

  environment_variables = {
    SQS_MAP   = jsonencode(var.sqs_map)
    LOG_LEVEL = var.log_level
  }

  attach_policy_json = true

  policy_json = data.aws_iam_policy_document.redrive_deadletter_lambda.json

  function_tags = var.tags
  role_tags     = var.tags
  tags          = var.tags

  depends_on = [aws_cloudwatch_log_group.redrive_deadletter_lambda]
}

data "aws_iam_policy_document" "redrive_deadletter_lambda" {
  statement {
    sid    = "SQSReceiveFromDLQ"
    effect = "Allow"

    actions = [
      "sqs:StartMessageMoveTask",
      "sqs:ReceiveMessage",
      "sqs:GetQueueAttributes",
      "sqs:DeleteMessage",
    ]

    resources = [
      for key, cfg in var.sqs_map :
      cfg.dlq
    ]
  }

  statement {
    sid    = "SQSSendToMainQueue"
    effect = "Allow"

    actions = [
      "sqs:SendMessage",
    ]

    resources = [
      for key, cfg in var.sqs_map :
      cfg.main
    ]
  }
}



resource "aws_cloudwatch_log_group" "redrive_deadletter_lambda" {
  name              = "/aws/lambda/${var.prefix}-redrive-deadletter"
  retention_in_days = var.logging_retention_in_days
  tags              = var.tags
  tags_all          = var.tags
}

resource "aws_cloudwatch_event_rule" "redrive_deadletter_lambda" {
  name                = "${var.prefix}-redrive-deadletter"
  description         = "Trigger Lambda every 10 minutes"
  schedule_expression = "cron(*/10 * * * ? *)"

  tags     = var.tags
  tags_all = var.tags

  depends_on = [module.redrive_deadletter_lambda]
}

resource "aws_cloudwatch_event_target" "redrive_deadletter_lambda" {
  rule = aws_cloudwatch_event_rule.redrive_deadletter_lambda.name
  arn  = module.redrive_deadletter_lambda.lambda_function_arn

  depends_on = [module.redrive_deadletter_lambda]
}

resource "aws_lambda_permission" "redrive_deadletter_lambda" {
  action        = "lambda:InvokeFunction"
  function_name = "${var.prefix}-redrive-deadletter"
  principal     = "events.amazonaws.com"
  statement_id  = "AllowExecutionFromCloudWatch"
  source_arn    = aws_cloudwatch_event_rule.redrive_deadletter_lambda.arn

  depends_on = [module.redrive_deadletter_lambda]
}
