

# Webhook relay: HTTP API -> EventBridge source bus -> cross-account destination bus

data "aws_caller_identity" "current" {}

locals {
  webhook           = "webhook"
  destination_bus   = "arn:aws:events:${var.destination_region}:${var.destination_account_id}:event-bus/${var.destination_event_bus_name}"
  api_name          = "${var.name_prefix}-http-api"
  rule_name         = "${var.name_prefix}-forward"
  forward_role_name = "${var.name_prefix}-events-forward"
}


# HTTP API Gateway -> Lambda integration
resource "aws_apigatewayv2_api" "webhook" {
  name          = local.api_name
  description   = "GitHub Webhook relay API Gateway"
  protocol_type = "HTTP"
  tags          = var.tags
  tags_all      = var.tags
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
  tags        = var.tags
  tags_all    = var.tags
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
  log_config {
    include_detail = "FULL"
    level          = "INFO"
  }
  tags     = var.tags
  tags_all = var.tags
}

# CloudWatch Log Delivery Sources for INFO, ERROR logs
resource "aws_cloudwatch_log_delivery_source" "info_logs" {
  name         = "${aws_cloudwatch_event_bus.source.name}-INFO_LOGS"
  log_type     = "INFO_LOGS"
  resource_arn = aws_cloudwatch_event_bus.source.arn
  tags         = var.tags
}

resource "aws_cloudwatch_log_delivery_source" "error_logs" {
  name         = "${aws_cloudwatch_event_bus.source.name}-ERROR_LOGS"
  log_type     = "ERROR_LOGS"
  resource_arn = aws_cloudwatch_event_bus.source.arn
  tags         = var.tags
}

# Logging to CloudWatch Log Group
resource "aws_cloudwatch_log_group" "event_bus_logs" {
  name              = "/aws/vendedlogs/events/event-bus/${aws_cloudwatch_event_bus.source.name}"
  retention_in_days = var.log_retention_in_days
  tags              = var.tags
  tags_all          = var.tags
}

data "aws_iam_policy_document" "cwlogs" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "${aws_cloudwatch_log_group.event_bus_logs.arn}:log-stream:*"
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values = [
        aws_cloudwatch_log_delivery_source.info_logs.arn,
        aws_cloudwatch_log_delivery_source.error_logs.arn
      ]
    }
  }
}

resource "aws_cloudwatch_log_resource_policy" "source" {
  policy_document = data.aws_iam_policy_document.cwlogs.json
  policy_name     = "AWSLogDeliveryWrite-${aws_cloudwatch_event_bus.source.name}"

}

resource "aws_cloudwatch_log_delivery_destination" "cwlogs" {
  name = "${aws_cloudwatch_event_bus.source.name}-CWLogs"
  delivery_destination_configuration {
    destination_resource_arn = aws_cloudwatch_log_group.event_bus_logs.arn
  }
  tags = var.tags
}

resource "aws_cloudwatch_log_delivery" "cwlogs_info_logs" {
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.cwlogs.arn
  delivery_source_name     = aws_cloudwatch_log_delivery_source.info_logs.name
  tags                     = var.tags
}

resource "aws_cloudwatch_log_delivery" "cwlogs_error_logs" {
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.cwlogs.arn
  delivery_source_name     = aws_cloudwatch_log_delivery_source.error_logs.name
  depends_on = [
    aws_cloudwatch_log_delivery.cwlogs_info_logs
  ]
  tags = var.tags
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
  tags               = var.tags
  tags_all           = var.tags
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
  event_pattern  = jsonencode({ source = ["github.webhook"] })
  tags           = var.tags
}

resource "aws_cloudwatch_event_target" "dest" {
  rule           = aws_cloudwatch_event_rule.forward.name
  event_bus_name = aws_cloudwatch_event_rule.forward.event_bus_name
  arn            = local.destination_bus
  role_arn       = aws_iam_role.events_forward.arn
}
