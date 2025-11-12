module "update_ec2_tags" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.1.2"

  function_name = "${var.runner_configs.prefix}-update-ec2-tags"
  handler       = "update_ec2_tags.lambda_handler"
  runtime       = "python3.12"
  timeout       = 900
  architectures = ["x86_64"]

  source_path = [{
    path = "${path.module}/lambda"
  }]

  logging_log_group                 = aws_cloudwatch_log_group.update_ec2_tags.name
  use_existing_cloudwatch_log_group = true

  trigger_on_package_timestamp = false

  environment_variables = {
    LOG_LEVEL = var.runner_configs.log_level
  }


  attach_policy_json = true

  policy_json = data.aws_iam_policy_document.update_ec2_tags.json

  function_tags = var.tenant_configs.tags
  role_tags     = var.tenant_configs.tags
  tags          = var.tenant_configs.tags

  depends_on = [aws_cloudwatch_log_group.update_ec2_tags]
}

data "aws_iam_policy_document" "update_ec2_tags" {

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
      values   = ["${var.runner_configs.prefix}-*"]
    }
  }
}

resource "aws_cloudwatch_log_group" "update_ec2_tags" {
  name              = "/aws/lambda/${var.runner_configs.prefix}-update-ec2-tags"
  retention_in_days = var.runner_configs.logging_retention_in_days
  tags              = var.tenant_configs.tags
  tags_all          = var.tenant_configs.tags
}

resource "aws_lambda_permission" "update_ec2_tags" {
  action        = "lambda:InvokeFunction"
  function_name = "${var.runner_configs.prefix}-update-ec2-tags"
  principal     = "events.amazonaws.com"
  statement_id  = "AllowExecutionFromCloudWatch"
  source_arn    = aws_cloudwatch_event_rule.update_ec2_tags.arn

  depends_on = [module.update_ec2_tags]
}

resource "aws_cloudwatch_event_rule" "update_ec2_tags" {
  name           = "${var.runner_configs.prefix}-update-ec2-tags"
  description    = "Workflow job event rule to update EC2 tags."
  event_bus_name = module.runners.webhook.eventbridge.event_bus.name

  tags     = var.tenant_configs.tags
  tags_all = var.tenant_configs.tags

  event_pattern = <<EOF
{
  "detail-type": ["workflow_job"],
  "detail": {
    "action": ["in_progress","completed"]
  }
}
EOF
}

resource "aws_cloudwatch_event_target" "update_ec2_tags" {
  arn            = module.update_ec2_tags.lambda_function_arn
  rule           = aws_cloudwatch_event_rule.update_ec2_tags.name
  event_bus_name = module.runners.webhook.eventbridge.event_bus.name
}
