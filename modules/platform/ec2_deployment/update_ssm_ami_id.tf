locals {
  runner_ami_map = {
    for key in keys(var.runner_configs.runner_specs) :
    key => {
      ssm_id     = split("parameter", module.runners.runners_map[key].launch_template_ami_id)[1]
      ami_filter = var.runner_configs.runner_specs[key].ami_filter
      ami_owners = var.runner_configs.runner_specs[key].ami_owners
    }
  }

  runner_ami_map_json = jsonencode(local.runner_ami_map)
}

module "update_runner_ami_lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.1.0"

  function_name = "${var.runner_configs.prefix}-update-runner-ami"
  handler       = "update_ssm_ami_id.lambda_handler"
  runtime       = "python3.11"

  source_path = [{
    path             = "${path.module}/lambda"
    pip_requirements = "${path.module}/lambda/requirements.txt"
  }]

  logging_log_group                 = aws_cloudwatch_log_group.update_runner_ami_lambda.name
  use_existing_cloudwatch_log_group = true

  environment_variables = {
    RUNNER_AMI_MAP = local.runner_ami_map_json
  }

  attach_policy_json = true

  policy_json = data.aws_iam_policy_document.update_runner_ami_lambda.json

  function_tags = var.tenant_configs.tags
  role_tags     = var.tenant_configs.tags
  tags          = var.tenant_configs.tags

  depends_on = [aws_cloudwatch_log_group.update_runner_ami_lambda]
}

data "aws_iam_policy_document" "update_runner_ami_lambda" {

  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    effect    = "Allow"
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:PutParameter",
      "ssm:AddTagsToResource"
    ]

    resources = [
      for key in keys(var.runner_configs.runner_specs) :
      replace(module.runners.runners_map[key].launch_template_ami_id, "resolve:ssm:", "")
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeImages"
    ]
    resources = ["*"]
  }
}

resource "aws_cloudwatch_log_group" "update_runner_ami_lambda" {
  name              = "/aws/lambda/${var.runner_configs.prefix}-update-runner-ami"
  retention_in_days = var.runner_configs.logging_retention_in_days
  tags              = var.tenant_configs.tags
  tags_all          = var.tenant_configs.tags
}

resource "aws_cloudwatch_event_rule" "update_runner_ami_lambda" {
  name                = "${var.runner_configs.prefix}-update-runner-ami-ten-minutes-rule"
  description         = "Trigger Lambda every 10 minutes"
  schedule_expression = "cron(*/10 * * * ? *)"

  tags     = var.tenant_configs.tags
  tags_all = var.tenant_configs.tags

  depends_on = [module.update_runner_ami_lambda]
}

resource "aws_cloudwatch_event_target" "update_runner_ami_lambda" {
  rule = aws_cloudwatch_event_rule.update_runner_ami_lambda.name
  arn  = module.update_runner_ami_lambda.lambda_function_arn

  depends_on = [module.update_runner_ami_lambda]
}

resource "aws_lambda_permission" "update_runner_ami_lambda" {
  action        = "lambda:InvokeFunction"
  function_name = "${var.runner_configs.prefix}-update-runner-ami"
  principal     = "events.amazonaws.com"
  statement_id  = "AllowExecutionFromCloudWatch"
  source_arn    = aws_cloudwatch_event_rule.update_runner_ami_lambda.arn

  depends_on = [module.update_runner_ami_lambda]
}
