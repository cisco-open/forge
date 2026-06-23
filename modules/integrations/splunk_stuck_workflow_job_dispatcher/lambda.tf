resource "aws_cloudwatch_log_group" "dispatcher" {
  name              = "/aws/lambda/${var.name_prefix}"
  retention_in_days = var.logging_retention_in_days
  tags              = local.all_security_tags
  tags_all          = local.all_security_tags
}

module "dispatcher" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.8.0"

  function_name = var.name_prefix
  handler       = "handler.lambda_handler"
  runtime       = "python3.12"
  timeout       = 60
  architectures = ["x86_64"]

  source_path = [{
    path = "${path.module}/lambda"
  }]

  logging_log_group                 = aws_cloudwatch_log_group.dispatcher.name
  use_existing_cloudwatch_log_group = true

  trigger_on_package_timestamp = false

  environment_variables = {
    DEDUPE_TABLE       = aws_dynamodb_table.dedupe.name
    DEDUPE_TTL_SECONDS = tostring(var.dedupe_ttl_seconds)
    LOG_LEVEL          = var.log_level
    WEBHOOK_TOKEN      = random_password.webhook_token.result
  }

  attach_policy_json = true
  policy_json        = data.aws_iam_policy_document.dispatcher.json

  function_tags = local.all_security_tags
  role_tags     = local.all_security_tags
  tags          = local.all_security_tags

  depends_on = [aws_cloudwatch_log_group.dispatcher]
}

data "aws_iam_policy_document" "dispatcher" {
  statement {
    sid    = "CreateDedupeRecords"
    effect = "Allow"
    actions = [
      "dynamodb:PutItem",
    ]
    resources = [aws_dynamodb_table.dedupe.arn]
  }
}

resource "aws_cloudwatch_log_group" "worker" {
  name              = "/aws/lambda/${var.name_prefix}-worker"
  retention_in_days = var.logging_retention_in_days
  tags              = local.all_security_tags
  tags_all          = local.all_security_tags
}

module "worker" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.8.0"

  function_name = "${var.name_prefix}-worker"
  handler       = "worker.lambda_handler"
  runtime       = "python3.12"
  timeout       = 900
  architectures = ["x86_64"]

  source_path = [{
    path = "${path.module}/lambda"
  }]

  logging_log_group                 = aws_cloudwatch_log_group.worker.name
  use_existing_cloudwatch_log_group = true

  trigger_on_package_timestamp = false

  environment_variables = {
    DEDUPE_TABLE                   = aws_dynamodb_table.dedupe.name
    LOG_LEVEL                      = var.log_level
    TENANT_CONFIG_PARAMETER_COUNT  = tostring(length(local.redelivery_tenant_config_chunks))
    TENANT_CONFIG_PARAMETER_PREFIX = local.redelivery_tenant_config_parameter_prefix
  }

  attach_policy_json = true
  policy_json        = data.aws_iam_policy_document.worker.json

  function_tags = local.all_security_tags
  role_tags     = local.all_security_tags
  tags          = local.all_security_tags

  depends_on = [
    aws_cloudwatch_log_group.worker,
    aws_ssm_parameter.tenant_configs,
  ]
}

resource "aws_lambda_event_source_mapping" "worker_from_dedupe_stream" {
  event_source_arn  = aws_dynamodb_table.dedupe.stream_arn
  function_name     = module.worker.lambda_function_arn
  starting_position = "LATEST"
  batch_size        = 10
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "worker" {
  statement {
    sid    = "ReadDedupeStream"
    effect = "Allow"
    actions = [
      "dynamodb:DescribeStream",
      "dynamodb:GetRecords",
      "dynamodb:GetShardIterator",
      "dynamodb:ListStreams",
    ]
    resources = [aws_dynamodb_table.dedupe.stream_arn]
  }

  statement {
    sid    = "UpdateDedupeRecords"
    effect = "Allow"
    actions = [
      "dynamodb:UpdateItem",
    ]
    resources = [aws_dynamodb_table.dedupe.arn]
  }

  statement {
    sid    = "ReadTenantGitHubAppParameters"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
    ]
    resources = [
      "arn:aws:ssm:*:${data.aws_caller_identity.current.account_id}:parameter/forge/*/github_app_*",
    ]
  }

  statement {
    sid    = "ReadDispatcherTenantConfigParameters"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
    ]
    resources = [
      for parameter in aws_ssm_parameter.tenant_configs : parameter.arn
    ]
  }

  statement {
    sid       = "DecryptTenantGitHubAppParameters"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "kms:ViaService"
      values   = ["ssm.*.amazonaws.com"]
    }
  }
}
