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

## GitHub Clean Global Lock Lambda
module "clean_global_lock_lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.1.0"

  function_name = "${var.deployment_config.prefix}-clean-global-lock"
  handler       = "github_clean_global_lock.lambda_handler"
  runtime       = "python3.11"
  timeout       = 120
  architectures = ["x86_64"]

  source_path = [{
    path             = "${path.module}/lambda"
    pip_requirements = "${path.module}/lambda/requirements.txt"
  }]
  build_in_docker  = true
  docker_image     = "public.ecr.aws/lambda/python:3.11"
  docker_pip_cache = false

  logging_log_group                 = aws_cloudwatch_log_group.clean_global_lock_lambda.name
  use_existing_cloudwatch_log_group = true

  environment_variables = {
    DYNAMODB_TABLE              = "${var.deployment_config.prefix}-gh-actions-lock"
    SECRET_NAME_APP_ID          = "${local.cicd_secrets_prefix}github_actions_runners_app_id"
    SECRET_NAME_PRIVATE_KEY     = "${local.cicd_secrets_prefix}github_actions_runners_app_key"
    SECRET_NAME_INSTALLATION_ID = "${local.cicd_secrets_prefix}github_actions_runners_app_installation_id"
  }

  attach_policy_json = true

  policy_json = data.aws_iam_policy_document.clean_global_lock_lambda.json

  function_tags = local.all_security_tags
  role_tags     = local.all_security_tags
  tags          = local.all_security_tags

  depends_on = [aws_cloudwatch_log_group.clean_global_lock_lambda]
}

data "aws_iam_policy_document" "clean_global_lock_lambda" {
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

resource "aws_cloudwatch_log_group" "clean_global_lock_lambda" {
  name              = "/aws/lambda/${var.deployment_config.prefix}-clean-global-lock"
  retention_in_days = var.logging_retention_in_days
  tags              = local.all_security_tags
  tags_all          = local.all_security_tags
}


resource "aws_cloudwatch_event_rule" "clean_global_lock_lambda" {
  name                = "${var.deployment_config.prefix}-clean-global-lock-ten-minutes-rule"
  description         = "Trigger Lambda every 10 minutes"
  schedule_expression = "cron(*/10 * * * ? *)"

  tags     = local.all_security_tags
  tags_all = local.all_security_tags

  depends_on = [module.clean_global_lock_lambda]
}

resource "aws_cloudwatch_event_target" "clean_global_lock_lambda" {
  rule = aws_cloudwatch_event_rule.clean_global_lock_lambda.name
  arn  = module.clean_global_lock_lambda.lambda_function_arn

  depends_on = [module.clean_global_lock_lambda]
}

resource "aws_lambda_permission" "clean_global_lock_lambda" {
  action        = "lambda:InvokeFunction"
  function_name = "${var.deployment_config.prefix}-clean-global-lock"
  principal     = "events.amazonaws.com"
  statement_id  = "AllowExecutionFromCloudWatch"
  source_arn    = aws_cloudwatch_event_rule.clean_global_lock_lambda.arn

  depends_on = [module.clean_global_lock_lambda]
}
