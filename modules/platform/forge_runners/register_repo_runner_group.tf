data "external" "install_dependencies_runner_group" {
  program = ["bash", "${path.module}/scripts/requirements_runner_group.sh", "/tmp/lambda_runner_group-${var.env}-${var.deployment_config.prefix}/"]
}

data "archive_file" "lambda_zip_runner_group" {
  type       = "zip"
  source_dir = data.external.install_dependencies_runner_group.result["lambda_package_dir"]

  output_path = "/tmp/lambda_runner_group-${var.env}-${var.deployment_config.prefix}-lambda_function.zip"
  depends_on  = [data.external.install_dependencies_runner_group]
}

resource "aws_lambda_function" "github_app_runner_group_lambda" {
  function_name    = "${var.deployment_config.prefix}-github-app-runner-group"
  filename         = data.archive_file.lambda_zip_runner_group.output_path
  source_code_hash = data.archive_file.lambda_zip_runner_group.output_base64sha256
  handler          = "github_app_runner_group.lambda_handler"
  architectures    = ["x86_64"]
  runtime          = "python3.11"
  role             = aws_iam_role.lambda_exec_runner_group.arn
  timeout          = 120

  environment {
    variables = {
      GITHUB_API                  = local.github_api
      ORGANIZATION                = var.ghes_org
      RUNNER_GROUP_NAME           = var.runner_group_name
      SECRET_NAME_APP_ID          = "${local.cicd_secrets_prefix}github_actions_runners_app_id"
      SECRET_NAME_PRIVATE_KEY     = "${local.cicd_secrets_prefix}github_actions_runners_app_key"
      SECRET_NAME_INSTALLATION_ID = "${local.cicd_secrets_prefix}github_actions_runners_app_installation_id"
    }
  }
  depends_on = [data.external.install_dependencies_runner_group]

  tags     = local.all_security_tags
  tags_all = local.all_security_tags
}

resource "aws_cloudwatch_event_rule" "sync_runner_group" {
  name                = "${var.deployment_config.prefix}-runner-group-sync"
  description         = "Trigger Lambda every 10 minutes to sync GitHub App runner group"
  schedule_expression = "cron(*/10 * * * ? *)"

  tags     = local.all_security_tags
  tags_all = local.all_security_tags
}

resource "aws_cloudwatch_event_target" "lambda_target_runner_group" {
  rule = aws_cloudwatch_event_rule.sync_runner_group.name
  arn  = aws_lambda_function.github_app_runner_group_lambda.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_runner_group" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.github_app_runner_group_lambda.function_name
  principal     = "events.amazonaws.com"
  statement_id  = "AllowExecutionFromCloudWatch"
  source_arn    = aws_cloudwatch_event_rule.sync_runner_group.arn
}

resource "aws_iam_role" "lambda_exec_runner_group" {
  name = "${var.deployment_config.prefix}-runner-group-lambda-exec-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags     = local.all_security_tags
  tags_all = local.all_security_tags
}

data "aws_iam_policy_document" "lambda_policy_document_runner_group" {
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

resource "aws_iam_policy" "lambda_policy_runner_group" {
  name        = "${var.deployment_config.prefix}-runner_group_lambda_policy"
  description = "IAM policy for Lambda logging"
  policy      = data.aws_iam_policy_document.lambda_policy_document_runner_group.json

  tags     = local.all_security_tags
  tags_all = local.all_security_tags
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment_runner_group" {
  role       = aws_iam_role.lambda_exec_runner_group.name
  policy_arn = aws_iam_policy.lambda_policy_runner_group.arn
}

resource "aws_cloudwatch_log_group" "github_app_runner_group_lambda" {
  name              = "/aws/lambda/${aws_lambda_function.github_app_runner_group_lambda.function_name}"
  retention_in_days = var.logging_retention_in_days
  tags              = local.all_security_tags
  tags_all          = local.all_security_tags
}
