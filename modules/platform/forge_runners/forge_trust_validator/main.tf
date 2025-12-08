module "forge_trust_validator_lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.1.2"

  function_name = "${var.prefix}-forge-trust-validator"
  handler       = "forge_trust_validator.lambda_handler"
  runtime       = "python3.12"
  timeout       = 900
  architectures = ["x86_64"]

  source_path = [{
    path = "${path.module}/lambda"
  }]

  logging_log_group                 = aws_cloudwatch_log_group.forge_trust_validator_lambda.name
  use_existing_cloudwatch_log_group = true

  trigger_on_package_timestamp = false

  environment_variables = {
    FORGE_IAM_ROLES  = join(",", [for key, arn in var.forge_iam_roles : arn])
    TENANT_IAM_ROLES = join(",", var.tenant_iam_roles)
    LOG_LEVEL        = var.log_level
  }

  attach_policy_json = true

  policy_json = data.aws_iam_policy_document.forge_trust_validator_lambda.json

  function_tags = var.tags
  role_tags     = var.tags
  tags          = var.tags

  depends_on = [aws_cloudwatch_log_group.forge_trust_validator_lambda]
}

data "aws_iam_policy_document" "forge_trust_validator_lambda" {
  statement {
    actions = [
      "iam:GetRole",
      "iam:UpdateAssumeRolePolicy",
      "sts:AssumeRole",
    ]
    effect    = "Allow"
    resources = [for key, arn in var.forge_iam_roles : arn]
  }
}

resource "aws_cloudwatch_log_group" "forge_trust_validator_lambda" {
  name              = "/aws/lambda/${var.prefix}-forge-trust-validator"
  retention_in_days = var.logging_retention_in_days
  tags              = var.tags
  tags_all          = var.tags
}

resource "aws_cloudwatch_event_rule" "forge_trust_validator_lambda" {
  name                = "${var.prefix}-forge-trust-validator"
  description         = "Trigger Lambda every 10 minutes"
  schedule_expression = "cron(*/10 * * * ? *)"

  tags     = var.tags
  tags_all = var.tags

  depends_on = [module.forge_trust_validator_lambda]
}

resource "aws_cloudwatch_event_target" "forge_trust_validator_lambda" {
  rule = aws_cloudwatch_event_rule.forge_trust_validator_lambda.name
  arn  = module.forge_trust_validator_lambda.lambda_function_arn

  depends_on = [module.forge_trust_validator_lambda]
}

resource "aws_lambda_permission" "forge_trust_validator_lambda" {
  action        = "lambda:InvokeFunction"
  function_name = "${var.prefix}-forge-trust-validator"
  principal     = "events.amazonaws.com"
  statement_id  = "AllowExecutionFromCloudWatch"
  source_arn    = aws_cloudwatch_event_rule.forge_trust_validator_lambda.arn

  depends_on = [module.forge_trust_validator_lambda]
}
