resource "aws_dynamodb_table" "lock_table" {
  name         = "${var.prefix}-gh-actions-lock"
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

  tags     = var.tags
  tags_all = var.tags
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
  name        = "${var.prefix}-dynamodb-put-delete-policy"
  description = "Allow PutItem and DeleteItem actions on DynamoDB table"
  policy      = data.aws_iam_policy_document.dynamodb_policy_document.json

  tags     = var.tags
  tags_all = var.tags
}

## GitHub Clean Global Lock Lambda
module "clean_global_lock_lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.1.0"

  function_name = "${var.prefix}-clean-global-lock"
  handler       = "github_clean_global_lock.lambda_handler"
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

  logging_log_group                 = aws_cloudwatch_log_group.clean_global_lock_lambda.name
  use_existing_cloudwatch_log_group = true

  trigger_on_package_timestamp = false

  environment_variables = {
    DYNAMODB_TABLE              = "${var.prefix}-gh-actions-lock"
    SECRET_NAME_APP_ID          = local.secrets.github_actions_runners_app_id.name
    SECRET_NAME_PRIVATE_KEY     = local.secrets.github_actions_runners_app_key.name
    SECRET_NAME_INSTALLATION_ID = local.secrets.github_actions_runners_app_installation_id.name
  }

  attach_policy_json = true

  policy_json = data.aws_iam_policy_document.clean_global_lock_lambda.json

  function_tags = var.tags
  role_tags     = var.tags
  tags          = var.tags

  depends_on = [aws_cloudwatch_log_group.clean_global_lock_lambda]
}

data "aws_iam_policy_document" "clean_global_lock_lambda" {
  statement {
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    effect = "Allow"
    resources = [
      data.aws_secretsmanager_secret_version.secrets["github_actions_runners_app_key"].arn,
      data.aws_secretsmanager_secret_version.secrets["github_actions_runners_app_id"].arn,
      data.aws_secretsmanager_secret_version.secrets["github_actions_runners_app_installation_id"].arn,
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
  name              = "/aws/lambda/${var.prefix}-clean-global-lock"
  retention_in_days = var.logging_retention_in_days
  tags              = var.tags
  tags_all          = var.tags
}


resource "aws_cloudwatch_event_rule" "clean_global_lock_lambda" {
  name                = "${var.prefix}-clean-global-lock"
  description         = "Trigger Lambda every 10 minutes"
  schedule_expression = "cron(*/10 * * * ? *)"

  tags     = var.tags
  tags_all = var.tags

  depends_on = [module.clean_global_lock_lambda]
}

resource "aws_cloudwatch_event_target" "clean_global_lock_lambda" {
  rule = aws_cloudwatch_event_rule.clean_global_lock_lambda.name
  arn  = module.clean_global_lock_lambda.lambda_function_arn

  depends_on = [module.clean_global_lock_lambda]
}

resource "aws_lambda_permission" "clean_global_lock_lambda" {
  action        = "lambda:InvokeFunction"
  function_name = "${var.prefix}-clean-global-lock"
  principal     = "events.amazonaws.com"
  statement_id  = "AllowExecutionFromCloudWatch"
  source_arn    = aws_cloudwatch_event_rule.clean_global_lock_lambda.arn

  depends_on = [module.clean_global_lock_lambda]
}
