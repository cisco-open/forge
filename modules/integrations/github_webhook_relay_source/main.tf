# Webhook relay: HTTP API -> EventBridge source bus -> cross-account destination bus

locals {
  webhook           = "webhook"
  destination_bus   = "arn:aws:events:${var.destination_region}:${var.destination_account_id}:event-bus/${var.destination_event_bus_name}"
  tags              = var.tags
  api_name          = "${var.name_prefix}-http-api"
  rule_name         = "${var.name_prefix}-forward"
  forward_role_name = "${var.name_prefix}-events-forward"
}


# HTTP API Gateway -> Lambda integration
resource "aws_apigatewayv2_api" "webhook" {
  name          = local.api_name
  description   = "GitHub Webhook relay API Gateway"
  protocol_type = "HTTP"
  tags          = local.tags
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id           = aws_apigatewayv2_api.webhook.id
  integration_type = "AWS_PROXY"
  integration_uri  = module.validate_signature_lambda.lambda_function_arn
}

resource "aws_apigatewayv2_route" "post_hook" {
  api_id    = aws_apigatewayv2_api.webhook.id
  route_key = "POST /webhook"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.webhook.id
  name        = "$default"
  auto_deploy = true
  tags        = local.tags
}

resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.validate_signature_lambda.lambda_function_arn
  principal     = "apigateway.amazonaws.com"
}

# EventBridge rule to forward to cross-account bus
resource "aws_cloudwatch_event_bus" "source" {
  name = var.source_event_bus_name
  tags = local.tags
}

data "aws_iam_policy_document" "events_forward_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "events_forward" {
  name               = local.forward_role_name
  assume_role_policy = data.aws_iam_policy_document.events_forward_assume_role.json
  tags               = local.tags
}

data "aws_iam_policy_document" "events_forward_permissions" {
  statement {
    effect    = "Allow"
    actions   = ["events:PutEvents"]
    resources = [local.destination_bus]
  }
}

resource "aws_iam_role_policy" "events_forward_put" {
  name   = "${local.forward_role_name}-policy"
  role   = aws_iam_role.events_forward.id
  policy = data.aws_iam_policy_document.events_forward_permissions.json
}

resource "aws_cloudwatch_event_rule" "forward" {
  name           = local.rule_name
  description    = "Forward webhook events to destination bus"
  event_bus_name = aws_cloudwatch_event_bus.source.name
  event_pattern  = jsonencode({})
  tags           = local.tags
}

resource "aws_cloudwatch_event_target" "dest" {
  rule           = aws_cloudwatch_event_rule.forward.name
  event_bus_name = aws_cloudwatch_event_rule.forward.event_bus_name
  arn            = local.destination_bus
  role_arn       = aws_iam_role.events_forward.arn
}
