module "ec2_update_runner_tags_lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.1.2"

  function_name = "${var.prefix}-ec2-update-runner-tags"
  handler       = "ec2_update_runner_tags.lambda_handler"
  runtime       = "python3.12"
  timeout       = 900
  architectures = ["x86_64"]

  source_path = [{
    path = "${path.module}/lambda"
  }]

  logging_log_group                 = aws_cloudwatch_log_group.ec2_update_runner_tags_lambda.name
  use_existing_cloudwatch_log_group = true

  trigger_on_package_timestamp = false

  environment_variables = {
    LOG_LEVEL = var.log_level
  }


  attach_policy_json = true

  policy_json = data.aws_iam_policy_document.ec2_update_runner_tags_lambda.json

  function_tags = var.tags
  role_tags     = var.tags
  tags          = var.tags

  depends_on = [aws_cloudwatch_log_group.ec2_update_runner_tags_lambda]
}

data "aws_iam_policy_document" "ec2_update_runner_tags_lambda" {

  # Allow DescribeInstances without condition
  statement {
    effect    = "Allow"
    actions   = ["ec2:DescribeInstances"]
    resources = ["*"]
  }

  # Allow tagging operations conditioned on environment tag
  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateTags",
      "ec2:DeleteTags"
    ]
    resources = ["*"]

    condition {
      test     = "StringLike"
      variable = "ec2:ResourceTag/ghr:environment"
      values   = ["${var.prefix}-*"]
    }
  }
}

resource "aws_cloudwatch_log_group" "ec2_update_runner_tags_lambda" {
  name              = "/aws/lambda/${var.prefix}-ec2-update-runner-tags"
  retention_in_days = var.logging_retention_in_days
  tags              = var.tags
  tags_all          = var.tags
}

resource "aws_lambda_permission" "ec2_update_runner_tags_lambda" {
  action        = "lambda:InvokeFunction"
  function_name = "${var.prefix}-ec2-update-runner-tags"
  principal     = "events.amazonaws.com"
  statement_id  = "AllowExecutionFromCloudWatch"
  source_arn    = aws_cloudwatch_event_rule.ec2_update_runner_tags_lambda.arn

  depends_on = [module.ec2_update_runner_tags_lambda]
}

resource "aws_cloudwatch_event_rule" "ec2_update_runner_tags_lambda" {
  name           = "${var.prefix}-ec2-update-runner-tags"
  description    = "Workflow job event rule to update EC2 tags."
  event_bus_name = var.event_bus

  tags     = var.tags
  tags_all = var.tags

  event_pattern = <<EOF
{
  "detail-type": ["workflow_job"],
  "detail": {
    "action": ["in_progress","completed"]
  }
}
EOF
}

resource "aws_cloudwatch_event_target" "ec2_update_runner_tags_lambda" {
  arn            = module.ec2_update_runner_tags_lambda.lambda_function_arn
  rule           = aws_cloudwatch_event_rule.ec2_update_runner_tags_lambda.name
  event_bus_name = var.event_bus
}
