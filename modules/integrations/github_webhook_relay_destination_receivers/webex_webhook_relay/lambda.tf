resource "aws_cloudwatch_log_group" "webex" {
  #checkov:skip=CKV_AWS_338:CloudWatch retention is intentionally operator-defined; teams may keep short CloudWatch windows when exporting logs to Splunk or Loki.
  name              = "/aws/lambda/webex-webhook-relay-destination-receiver"
  retention_in_days = var.logging_retention_in_days
  tags_all          = local.all_security_tags
  tags              = local.all_security_tags
}

module "webex" {
  #checkov:skip=CKV_TF_1:Module source uses Renovate-managed version tags; commit SHA pinning is an accepted policy tradeoff.
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.8.0"

  function_name = "webex-webhook-relay-destination-receiver"
  handler       = "handler.lambda_handler"
  runtime       = "python3.12"
  timeout       = 900
  architectures = ["x86_64"]

  source_path = [{
    path = "${path.module}/lambda"
  }]

  logging_log_group                 = aws_cloudwatch_log_group.webex.name
  use_existing_cloudwatch_log_group = true

  trigger_on_package_timestamp = false

  environment_variables = {
    WEBEX_BOT_TOKEN_SECRET_NAME = "/cicd/common/webex_webhook_relay_bot_token"
    LOG_LEVEL                   = var.log_level
  }

  attach_policy_json = true
  policy_json        = data.aws_iam_policy_document.secret.json

  function_tags = local.all_security_tags
  role_tags     = local.all_security_tags
  tags          = local.all_security_tags

  depends_on = [aws_cloudwatch_log_group.webex]
}
