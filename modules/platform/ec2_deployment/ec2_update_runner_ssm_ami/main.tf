module "ec2_update_runner_ssm_ami_lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.4.0"

  function_name = "${var.prefix}-ec2-update-runner-ssm-ami"
  handler       = "ec2_update_runner_ssm_ami.lambda_handler"
  runtime       = "python3.12"
  timeout       = 900
  architectures = ["x86_64"]

  source_path = [{
    path = "${path.module}/lambda"
  }]

  logging_log_group                 = aws_cloudwatch_log_group.ec2_update_runner_ssm_ami_lambda.name
  use_existing_cloudwatch_log_group = true

  trigger_on_package_timestamp = false

  environment_variables = {
    RUNNER_AMI_MAP = jsonencode(var.runner_ami_map)
    LOG_LEVEL      = var.log_level
  }

  attach_policy_json = true

  policy_json = data.aws_iam_policy_document.ec2_update_runner_ssm_ami_lambda.json

  function_tags = var.tags
  role_tags     = var.tags
  tags          = var.tags

  depends_on = [aws_cloudwatch_log_group.ec2_update_runner_ssm_ami_lambda]
}

data "aws_iam_policy_document" "ec2_update_runner_ssm_ami_lambda" {
  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:PutParameter",
      "ssm:AddTagsToResource"
    ]

    resources = [
      for key, cfg in var.runner_ami_map :
      cfg.resource_ssm_id
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeImages",
    ]
    resources = ["*"]
  }
}

resource "aws_cloudwatch_log_group" "ec2_update_runner_ssm_ami_lambda" {
  name              = "/aws/lambda/${var.prefix}-ec2-update-runner-ssm-ami"
  retention_in_days = var.logging_retention_in_days
  tags              = var.tags
  tags_all          = var.tags
}

resource "aws_cloudwatch_event_rule" "ec2_update_runner_ssm_ami_lambda" {
  name                = "${var.prefix}-ec2-update-runner-ssm-ami"
  description         = "Trigger Lambda every 10 minutes"
  schedule_expression = "cron(*/10 * * * ? *)"

  tags     = var.tags
  tags_all = var.tags

  depends_on = [module.ec2_update_runner_ssm_ami_lambda]
}

resource "aws_cloudwatch_event_target" "ec2_update_runner_ssm_ami_lambda" {
  rule = aws_cloudwatch_event_rule.ec2_update_runner_ssm_ami_lambda.name
  arn  = module.ec2_update_runner_ssm_ami_lambda.lambda_function_arn

  depends_on = [module.ec2_update_runner_ssm_ami_lambda]
}

resource "aws_lambda_permission" "ec2_update_runner_ssm_ami_lambda" {
  action        = "lambda:InvokeFunction"
  function_name = "${var.prefix}-ec2-update-runner-ssm-ami"
  principal     = "events.amazonaws.com"
  statement_id  = "AllowExecutionFromCloudWatch"
  source_arn    = aws_cloudwatch_event_rule.ec2_update_runner_ssm_ami_lambda.arn

  depends_on = [module.ec2_update_runner_ssm_ami_lambda]
}
