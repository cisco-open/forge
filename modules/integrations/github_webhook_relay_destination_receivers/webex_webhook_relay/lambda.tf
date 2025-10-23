resource "aws_cloudwatch_log_group" "webex" {
  name              = "/aws/lambda/webex-webhook-relay-destination-receiver"
  retention_in_days = var.log_retention_days
  tags_all          = local.all_security_tags
  tags              = local.all_security_tags
}

module "webex" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.1.2"

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
  }

  attach_policy_json = true
  policy_json        = data.aws_iam_policy_document.secret.json

  function_tags = local.all_security_tags
  role_tags     = local.all_security_tags
  tags          = local.all_security_tags

  depends_on = [aws_cloudwatch_log_group.webex]
}
