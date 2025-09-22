############################################################
# Webhook Relay Source (API Gateway HTTP API -> EventBridge -> XAcct)
############################################################
locals {
  webhook           = "webhook"
  dest_region       = var.destination_region
  destination_bus   = "arn:aws:events:${local.dest_region}:${var.destination_account_id}:event-bus/${var.destination_event_bus_name}"
  tags              = var.tags
  api_name          = "${var.name_prefix}-http-api"
  rule_name         = "${var.name_prefix}-forward"
  apigw_role_name   = "${var.name_prefix}-apigw-events"
  forward_role_name = "${var.name_prefix}-events-forward"
}

#####################################
# EventBridge (source) Bus
#####################################
resource "aws_cloudwatch_event_bus" "source" {
  name = var.source_event_bus_name
  tags = local.tags
}

#####################################
# IAM: API Gateway -> EventBridge
#####################################
resource "aws_iam_role" "apigw_events" {
  name = local.apigw_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "apigateway.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy" "apigw_put_events" {
  name = "${local.apigw_role_name}-policy"
  role = aws_iam_role.apigw_events.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["events:PutEvents"]
      Resource = aws_cloudwatch_event_bus.source.arn
    }]
  })
}

#####################################
# IAM: EventBridge Rule -> Destination Bus (cross-account)
#####################################
resource "aws_iam_role" "events_forward" {
  name = local.forward_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy" "events_forward_put" {
  name = "${local.forward_role_name}-policy"
  role = aws_iam_role.events_forward.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["events:PutEvents"]
      Resource = local.destination_bus
    }]
  })
}

#####################################
# API Gateway HTTP API -> EventBridge
#####################################
resource "aws_apigatewayv2_api" "webhook" {
  name          = local.api_name
  protocol_type = "HTTP"
  description   = "Generic webhook ingestion -> EventBridge (HTTP API)"
  tags          = local.tags
}

resource "aws_apigatewayv2_integration" "events" {
  api_id                 = aws_apigatewayv2_api.webhook.id
  integration_type       = "AWS_PROXY"
  integration_subtype    = "EventBridge-PutEvents"
  credentials_arn        = aws_iam_role.apigw_events.arn
  payload_format_version = "1.0"
  timeout_milliseconds   = 3000

  request_parameters = {
    Detail       = "$request.body"
    DetailType   = "generic.event"
    Source       = var.event_source
    EventBusName = var.source_event_bus_name
  }
}

resource "aws_apigatewayv2_route" "post_hook" {
  api_id    = aws_apigatewayv2_api.webhook.id
  route_key = "POST /${local.webhook}"
  target    = "integrations/${aws_apigatewayv2_integration.events.id}"
}

resource "aws_apigatewayv2_stage" "this" {
  api_id      = aws_apigatewayv2_api.webhook.id
  name        = "$default"
  auto_deploy = true
  tags        = local.tags
}

#####################################
# Event Forwarding Rule (Source -> Destination Bus)
#####################################
resource "aws_cloudwatch_event_rule" "forward" {
  name           = local.rule_name
  description    = "Forward webhook events to destination bus"
  event_bus_name = aws_cloudwatch_event_bus.source.name
  event_pattern  = jsonencode({ source = [var.event_source] })
  tags           = local.tags
}

resource "aws_cloudwatch_event_target" "dest" {
  rule           = aws_cloudwatch_event_rule.forward.name
  event_bus_name = aws_cloudwatch_event_rule.forward.event_bus_name
  arn            = local.destination_bus
  role_arn       = aws_iam_role.events_forward.arn
}
