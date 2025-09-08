module "register_github_app_runner_group_lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.1.0"

  function_name = "${var.deployment_config.prefix}-register-github-app-runner-group"
  handler       = "github_app_runner_group.lambda_handler"
  runtime       = "python3.11"
  timeout       = 900
  architectures = ["x86_64"]

  source_path = [{
    path             = "${path.module}/lambda"
    pip_requirements = "${path.module}/lambda/requirements.txt"
  }]

  logging_log_group                 = aws_cloudwatch_log_group.register_github_app_runner_group_lambda.name
  use_existing_cloudwatch_log_group = true

  environment_variables = {
    GITHUB_API                  = local.github_api
    ORGANIZATION                = var.ghes_org
    RUNNER_GROUP_NAME           = var.runner_group_name
    REPOSITORY_SELECTION        = var.repository_selection
    SECRET_NAME_APP_ID          = "${local.cicd_secrets_prefix}github_actions_runners_app_id"
    SECRET_NAME_PRIVATE_KEY     = "${local.cicd_secrets_prefix}github_actions_runners_app_key"
    SECRET_NAME_INSTALLATION_ID = "${local.cicd_secrets_prefix}github_actions_runners_app_installation_id"
  }

  attach_policy_json = true

  policy_json = data.aws_iam_policy_document.register_github_app_runner_group_lambda.json

  function_tags = local.all_security_tags
  role_tags     = local.all_security_tags
  tags          = local.all_security_tags

  depends_on = [aws_cloudwatch_log_group.register_github_app_runner_group_lambda]
}

data "aws_iam_policy_document" "register_github_app_runner_group_lambda" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    effect    = "Allow"
    resources = ["*"]
  }
  statement {
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    effect = "Allow"
    resources = [
      data.aws_secretsmanager_secret_version.data_cicd_secrets["${local.cicd_secrets_prefix}github_actions_runners_app_key"].arn,
      data.aws_secretsmanager_secret_version.data_cicd_secrets["${local.cicd_secrets_prefix}github_actions_runners_app_id"].arn,
      data.aws_secretsmanager_secret_version.data_cicd_secrets["${local.cicd_secrets_prefix}github_actions_runners_app_installation_id"].arn,
    ]
  }
}

resource "aws_cloudwatch_log_group" "register_github_app_runner_group_lambda" {
  name              = "/aws/lambda/${var.deployment_config.prefix}-register-github-app-runner-group"
  retention_in_days = var.logging_retention_in_days
  tags              = local.all_security_tags
  tags_all          = local.all_security_tags
}

resource "aws_cloudwatch_event_rule" "register_github_app_runner_group_lambda" {
  name                = "${var.deployment_config.prefix}-register-github-app-runner-group"
  description         = "Trigger Lambda every 10 minutes"
  schedule_expression = "cron(*/10 * * * ? *)"

  tags     = local.all_security_tags
  tags_all = local.all_security_tags

  depends_on = [module.register_github_app_runner_group_lambda]
}

resource "aws_cloudwatch_event_target" "register_github_app_runner_group_lambda" {
  rule = aws_cloudwatch_event_rule.register_github_app_runner_group_lambda.name
  arn  = module.register_github_app_runner_group_lambda.lambda_function_arn

  depends_on = [module.register_github_app_runner_group_lambda]
}

resource "aws_lambda_permission" "register_github_app_runner_group_lambda" {
  action        = "lambda:InvokeFunction"
  function_name = "${var.deployment_config.prefix}-register-github-app-runner-group"
  principal     = "events.amazonaws.com"
  statement_id  = "AllowExecutionFromCloudWatch"
  source_arn    = aws_cloudwatch_event_rule.register_github_app_runner_group_lambda.arn

  depends_on = [module.register_github_app_runner_group_lambda]
}
