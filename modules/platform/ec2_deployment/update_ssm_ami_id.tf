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

  # Build from local source
  source_path = [{
    path             = "${path.module}/lambda"
    pip_requirements = "${path.module}/lambda/requirements.txt"
  }]

  logging_log_group = aws_cloudwatch_log_group.update_runner_ami_lambda.name

  environment_variables = {
    RUNNER_AMI_MAP = local.runner_ami_map_json
  }

  attach_policy_json = true

  policy_json = data.aws_iam_policy_document.lambda_ssm_ami.json

  function_tags = var.tenant_configs.tags
  role_tags     = var.tenant_configs.tags
  tags          = var.tenant_configs.tags
}

data "aws_iam_policy_document" "lambda_ssm_ami" {

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
