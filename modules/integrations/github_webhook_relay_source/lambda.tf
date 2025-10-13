module "validate_signature_lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.1.0"

  function_name = "${var.name_prefix}-validate-signature"
  handler       = "validate_signature.lambda_handler"
  runtime       = "python3.12"
  timeout       = 900
  architectures = ["x86_64"]

  source_path = [{
    path = "${path.module}/lambda"
  }]

  logging_log_group                 = aws_cloudwatch_log_group.validate_signature_lambda.name
  use_existing_cloudwatch_log_group = true

  trigger_on_package_timestamp = false

  environment_variables = {
    EVENT_BUS      = var.source_event_bus_name
    WEBHOOK_SECRET = var.webhook_secret
  }

  attach_policy_json = true

  policy_json = data.aws_iam_policy_document.validate_signature_lambda.json

  function_tags = var.tags
  role_tags     = var.tags
  tags          = var.tags

  depends_on = [aws_cloudwatch_log_group.validate_signature_lambda]
}

data "aws_iam_policy_document" "validate_signature_lambda" {

  statement {
    effect = "Allow"
    actions = [
      "events:PutEvents"
    ]
    resources = [
      aws_cloudwatch_event_bus.source.arn
    ]
  }
}

resource "aws_cloudwatch_log_group" "validate_signature_lambda" {
  name              = "/aws/lambda/${var.name_prefix}-validate-signature"
  retention_in_days = var.log_retention_in_days
  tags              = var.tags
  tags_all          = var.tags
}
