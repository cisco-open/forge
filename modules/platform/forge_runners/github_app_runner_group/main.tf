module "register_github_app_runner_group_lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.5.0"

  function_name = "${var.prefix}-register-github-app-runner-group"
  handler       = "github_app_runner_group.lambda_handler"
  runtime       = "python3.12"
  timeout       = 900
  architectures = ["x86_64"]

  source_path = [{
    path = "${path.module}/lambda"
  }]

  layers = [
    "arn:aws:lambda:${data.aws_region.current.region}:770693421928:layer:Klayers-p312-cryptography:17",
    "arn:aws:lambda:${data.aws_region.current.region}:770693421928:layer:Klayers-p312-requests:17",
    "arn:aws:lambda:${data.aws_region.current.region}:770693421928:layer:Klayers-p312-PyJWT:1",
  ]

  logging_log_group                 = aws_cloudwatch_log_group.register_github_app_runner_group_lambda.name
  use_existing_cloudwatch_log_group = true

  trigger_on_package_timestamp = false

  environment_variables = {
    GITHUB_API                  = var.github_api
    ORGANIZATION                = var.ghes_org
    RUNNER_GROUP_NAME           = var.runner_group_name
    REPOSITORY_SELECTION        = var.repository_selection
    SECRET_NAME_APP_ID          = var.github_app.id_ssm.arn
    SECRET_NAME_PRIVATE_KEY     = var.github_app.key_base64_ssm.arn
    SECRET_NAME_INSTALLATION_ID = var.github_app.installation_id_ssm.arn
    LOG_LEVEL                   = var.log_level
  }

  attach_policy_json = true

  policy_json = data.aws_iam_policy_document.register_github_app_runner_group_lambda.json

  function_tags = var.tags
  role_tags     = var.tags
  tags          = var.tags

  depends_on = [aws_cloudwatch_log_group.register_github_app_runner_group_lambda]
}

data "aws_iam_policy_document" "register_github_app_runner_group_lambda" {
  statement {
    effect = "Allow"

    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParameterHistory",
      "ssm:DescribeParameters",
    ]

    resources = [
      var.github_app.id_ssm.arn,
      var.github_app.key_base64_ssm.arn,
      var.github_app.installation_id_ssm.arn,
    ]
  }
}

resource "aws_cloudwatch_log_group" "register_github_app_runner_group_lambda" {
  name              = "/aws/lambda/${var.prefix}-register-github-app-runner-group"
  retention_in_days = var.logging_retention_in_days
  tags              = var.tags
  tags_all          = var.tags
}

resource "aws_cloudwatch_event_rule" "register_github_app_runner_group_lambda" {
  name                = "${var.prefix}-register-github-app-runner-group"
  description         = "Trigger Lambda every 10 minutes"
  schedule_expression = "cron(*/10 * * * ? *)"

  tags     = var.tags
  tags_all = var.tags

  depends_on = [module.register_github_app_runner_group_lambda]
}

resource "aws_cloudwatch_event_target" "register_github_app_runner_group_lambda" {
  rule = aws_cloudwatch_event_rule.register_github_app_runner_group_lambda.name
  arn  = module.register_github_app_runner_group_lambda.lambda_function_arn

  depends_on = [module.register_github_app_runner_group_lambda]
}

resource "aws_lambda_permission" "register_github_app_runner_group_lambda" {
  action        = "lambda:InvokeFunction"
  function_name = "${var.prefix}-register-github-app-runner-group"
  principal     = "events.amazonaws.com"
  statement_id  = "AllowExecutionFromCloudWatch"
  source_arn    = aws_cloudwatch_event_rule.register_github_app_runner_group_lambda.arn

  depends_on = [module.register_github_app_runner_group_lambda]
}
