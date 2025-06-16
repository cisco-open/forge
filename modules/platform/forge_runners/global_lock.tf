resource "aws_dynamodb_table" "lock_table" {
  name         = "${var.deployment_config.prefix}-gh-actions-lock"
  billing_mode = "PAY_PER_REQUEST"

  hash_key = "lock_id"

  attribute {
    name = "lock_id"
    type = "S"
  }

  attribute {
    name = "workflow_run_id"
    type = "S"
  }

  attribute {
    name = "workflow_run_attempt"
    type = "S"
  }

  global_secondary_index {
    name            = "workflow_run_id_index"
    hash_key        = "workflow_run_id"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "workflow_run_attempt_index"
    hash_key        = "workflow_run_attempt"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "timestamp"
    enabled        = true
  }

  tags     = local.all_security_tags
  tags_all = local.all_security_tags
}

data "aws_iam_policy_document" "dynamodb_policy_document" {
  statement {
    effect = "Allow"

    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:Query",
      "dynamodb:DeleteItem"
    ]

    resources = [
      aws_dynamodb_table.lock_table.arn,
      "${aws_dynamodb_table.lock_table.arn}/*",
    ]
  }
}

resource "aws_iam_policy" "dynamodb_policy" {
  name        = "${var.deployment_config.prefix}-dynamodb-put-delete-policy"
  description = "Allow PutItem and DeleteItem actions on DynamoDB table"
  policy      = data.aws_iam_policy_document.dynamodb_policy_document.json

  tags     = local.all_security_tags
  tags_all = local.all_security_tags
}

data "external" "install_dependencies_global_lock" {
  program = ["bash", "${path.module}/scripts/requirements_clean_global_lock.sh", "/tmp/lambda_global_lock-${var.env}-${var.deployment_config.prefix}/"]
}

data "archive_file" "lambda_zip_global_lock" {
  type       = "zip"
  source_dir = data.external.install_dependencies_global_lock.result["lambda_package_dir"]

  output_path = "/tmp/lambda_global_lock-${var.env}-${var.deployment_config.prefix}-lambda_function.zip"
  depends_on  = [data.external.install_dependencies_global_lock]
}

resource "aws_lambda_function" "github_clean_global_lock_lambda" {
  function_name    = "${var.deployment_config.prefix}-github-clean-global-lock"
  filename         = data.archive_file.lambda_zip_global_lock.output_path
  source_code_hash = data.archive_file.lambda_zip_global_lock.output_base64sha256
  handler          = "github_clean_global_lock.lambda_handler"
  architectures    = ["x86_64"]
  runtime          = "python3.11"
  role             = aws_iam_role.lambda_exec_global_lock.arn
  timeout          = 120

  environment {
    variables = {
      DYNAMODB_TABLE              = "${var.deployment_config.prefix}-gh-actions-lock"
      SECRET_NAME_APP_ID          = "${local.cicd_secrets_prefix}github_actions_runners_app_id"
      SECRET_NAME_PRIVATE_KEY     = "${local.cicd_secrets_prefix}github_actions_runners_app_key"
      SECRET_NAME_INSTALLATION_ID = "${local.cicd_secrets_prefix}github_actions_runners_app_installation_id"
    }
  }
  depends_on = [data.external.install_dependencies_global_lock]

  tags     = local.all_security_tags
  tags_all = local.all_security_tags
}

resource "aws_cloudwatch_event_rule" "every_ten_minutes_global_lock" {
  name                = "${var.deployment_config.prefix}-global-lock-every-ten-minutes-rule"
  description         = "Trigger Lambda every 10 minutes"
  schedule_expression = "cron(*/10 * * * ? *)" # This cron expression triggers 10 minutes

  tags     = local.all_security_tags
  tags_all = local.all_security_tags
}

resource "aws_cloudwatch_event_target" "lambda_target_global_lock" {
  rule = aws_cloudwatch_event_rule.every_ten_minutes_global_lock.name
  arn  = aws_lambda_function.github_clean_global_lock_lambda.arn # The Lambda function ARN
}

resource "aws_lambda_permission" "allow_cloudwatch_global_lock" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.github_clean_global_lock_lambda.function_name
  principal     = "events.amazonaws.com"
  statement_id  = "AllowExecutionFromCloudWatch"
  source_arn    = aws_cloudwatch_event_rule.every_ten_minutes_global_lock.arn
}

resource "aws_iam_role" "lambda_exec_global_lock" {
  name = "${var.deployment_config.prefix}-global-lock-lambda-exec-role"
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

data "aws_iam_policy_document" "lambda_policy_document_global_lock" {
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
  statement {
    effect = "Allow"

    actions = [
      "dynamodb:Scan",
      "dynamodb:DeleteItem"
    ]

    resources = [
      aws_dynamodb_table.lock_table.arn,
    ]
  }
}

resource "aws_iam_policy" "lambda_policy_global_lock" {
  name        = "${var.deployment_config.prefix}-global-lock-lambda-policy"
  description = "IAM policy for Lambda logging"
  policy      = data.aws_iam_policy_document.lambda_policy_document_global_lock.json

  tags     = local.all_security_tags
  tags_all = local.all_security_tags
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment_global_lock" {
  role       = aws_iam_role.lambda_exec_global_lock.name
  policy_arn = aws_iam_policy.lambda_policy_global_lock.arn
}

resource "aws_cloudwatch_log_group" "github_clean_global_lock_lambda" {
  name              = "/aws/lambda/${aws_lambda_function.github_clean_global_lock_lambda.function_name}"
  retention_in_days = var.logging_retention_in_days
  tags              = local.all_security_tags
  tags_all          = local.all_security_tags
}
