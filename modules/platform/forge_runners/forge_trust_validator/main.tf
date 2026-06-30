locals {
  forge_trust_preparer_function_name  = "${var.prefix}-forge-trust-validator-prepare"
  forge_trust_validator_function_name = "${var.prefix}-forge-trust-validator"
  forge_trust_validator_role_arn      = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/${local.forge_trust_validator_function_name}"
}

module "forge_trust_preparer_lambda" {
  #checkov:skip=CKV_TF_1:Module source uses Renovate-managed version tags; commit SHA pinning is an accepted policy tradeoff.
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.8.0"

  function_name                  = local.forge_trust_preparer_function_name
  role_name                      = local.forge_trust_preparer_function_name
  handler                        = "trust_preparer.prepare_handler"
  runtime                        = "python3.12"
  timeout                        = 900
  reserved_concurrent_executions = 1
  architectures                  = ["x86_64"]

  source_path = [{
    path = "${path.module}/lambda"
  }]

  logging_log_group                 = aws_cloudwatch_log_group.forge_trust_preparer_lambda.name
  use_existing_cloudwatch_log_group = true

  trigger_on_package_timestamp = false

  environment_variables = {
    FORGE_IAM_ROLES           = join(",", [for key, arn in var.forge_iam_roles : arn])
    TENANT_IAM_ROLES          = join(",", var.tenant_iam_roles)
    VALIDATOR_LAMBDA_ROLE_ARN = local.forge_trust_validator_role_arn
    VALIDATION_QUEUE_URL      = aws_sqs_queue.forge_trust_validator.url
    VALIDATION_DELAY_SECONDS  = tostring(var.iam_propagation_delay_seconds)
    LOG_LEVEL                 = var.log_level
  }

  function_tags = var.tags
  role_tags     = var.tags
  tags          = var.tags

  depends_on = [aws_cloudwatch_log_group.forge_trust_preparer_lambda]
}

module "forge_trust_validator_lambda" {
  #checkov:skip=CKV_TF_1:Module source uses Renovate-managed version tags; commit SHA pinning is an accepted policy tradeoff.
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.8.0"

  function_name                  = local.forge_trust_validator_function_name
  role_name                      = local.forge_trust_validator_function_name
  handler                        = "trust_validator.validate_handler"
  runtime                        = "python3.12"
  timeout                        = 900
  reserved_concurrent_executions = 1
  architectures                  = ["x86_64"]

  source_path = [{
    path = "${path.module}/lambda"
  }]

  logging_log_group                 = aws_cloudwatch_log_group.forge_trust_validator_lambda.name
  use_existing_cloudwatch_log_group = true

  trigger_on_package_timestamp = false

  environment_variables = {
    LOG_LEVEL = var.log_level
  }

  function_tags = var.tags
  role_tags     = var.tags
  tags          = var.tags

  depends_on = [aws_cloudwatch_log_group.forge_trust_validator_lambda]
}

data "aws_iam_policy_document" "forge_trust_preparer_lambda" {
  statement {
    sid = "AllowUpdateForgeRoleTrustPolicies"

    actions = [
      "iam:GetRole",
      "iam:UpdateAssumeRolePolicy",
    ]
    effect    = "Allow"
    resources = [for key, arn in var.forge_iam_roles : arn]
  }

  statement {
    sid = "AllowSendDelayedValidationMessages"

    actions = [
      "sqs:SendMessage",
    ]
    effect    = "Allow"
    resources = [aws_sqs_queue.forge_trust_validator.arn]
  }
}

data "aws_iam_policy_document" "forge_trust_validator_lambda" {
  statement {
    sid = "AllowUpdateForgeRoleTrustPolicies"

    actions = [
      "iam:GetRole",
      "iam:UpdateAssumeRolePolicy",
    ]
    effect    = "Allow"
    resources = [for key, arn in var.forge_iam_roles : arn]
  }

  statement {
    sid = "AllowAssumeForgeRolesForValidation"

    actions = [
      "sts:AssumeRole",
    ]
    effect    = "Allow"
    resources = [for key, arn in var.forge_iam_roles : arn]
  }

  statement {
    sid = "AllowDelayedValidationQueueAccess"

    actions = [
      "sqs:ChangeMessageVisibility",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:ReceiveMessage",
    ]
    effect    = "Allow"
    resources = [aws_sqs_queue.forge_trust_validator.arn]
  }
}

resource "aws_iam_role_policy" "forge_trust_preparer_lambda" {
  name   = "${local.forge_trust_preparer_function_name}-forge-role-preparation"
  role   = module.forge_trust_preparer_lambda.lambda_role_name
  policy = data.aws_iam_policy_document.forge_trust_preparer_lambda.json
}

resource "aws_iam_role_policy" "forge_trust_validator_lambda" {
  name   = "${local.forge_trust_validator_function_name}-forge-role-validation"
  role   = module.forge_trust_validator_lambda.lambda_role_name
  policy = data.aws_iam_policy_document.forge_trust_validator_lambda.json
}

resource "aws_sqs_queue" "forge_trust_validator" {
  name                       = "${local.forge_trust_validator_function_name}-delay"
  message_retention_seconds  = 86400
  visibility_timeout_seconds = 960

  tags     = var.tags
  tags_all = var.tags
}

resource "aws_cloudwatch_log_group" "forge_trust_preparer_lambda" {
  name              = "/aws/lambda/${local.forge_trust_preparer_function_name}"
  retention_in_days = var.logging_retention_in_days
  tags              = var.tags
  tags_all          = var.tags
}

resource "aws_cloudwatch_log_group" "forge_trust_validator_lambda" {
  name              = "/aws/lambda/${local.forge_trust_validator_function_name}"
  retention_in_days = var.logging_retention_in_days
  tags              = var.tags
  tags_all          = var.tags
}

resource "aws_cloudwatch_event_rule" "forge_trust_preparer_lambda" {
  name                = local.forge_trust_preparer_function_name
  description         = "Trigger Forge trust validation preparation every 10 minutes"
  schedule_expression = "cron(*/10 * * * ? *)"

  tags     = var.tags
  tags_all = var.tags

  depends_on = [module.forge_trust_preparer_lambda]
}

resource "aws_cloudwatch_event_target" "forge_trust_preparer_lambda" {
  rule = aws_cloudwatch_event_rule.forge_trust_preparer_lambda.name
  arn  = module.forge_trust_preparer_lambda.lambda_function_arn

  depends_on = [
    module.forge_trust_preparer_lambda,
    aws_iam_role_policy.forge_trust_preparer_lambda,
  ]
}

resource "aws_lambda_event_source_mapping" "forge_trust_validator_lambda" {
  event_source_arn = aws_sqs_queue.forge_trust_validator.arn
  function_name    = module.forge_trust_validator_lambda.lambda_function_arn
  batch_size       = 1
  enabled          = true

  depends_on = [
    module.forge_trust_validator_lambda,
    aws_iam_role_policy.forge_trust_validator_lambda,
  ]
}

resource "aws_lambda_permission" "forge_trust_preparer_lambda" {
  action        = "lambda:InvokeFunction"
  function_name = local.forge_trust_preparer_function_name
  principal     = "events.amazonaws.com"
  statement_id  = "AllowExecutionFromCloudWatch"
  source_arn    = aws_cloudwatch_event_rule.forge_trust_preparer_lambda.arn

  depends_on = [module.forge_trust_preparer_lambda]
}
