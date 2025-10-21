resource "aws_cloudwatch_event_bus" "destination" {
  name = var.webhook_relay_destination_config.destination_event_bus_name
  log_config {
    include_detail = "NONE"
    level          = "OFF"
  }
  tags     = local.all_security_tags
  tags_all = local.all_security_tags
}

resource "aws_cloudwatch_event_bus_policy" "allow_source" {
  event_bus_name = aws_cloudwatch_event_bus.destination.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowSourceAccountPutEvents"
        Effect    = "Allow"
        Principal = { AWS = var.webhook_relay_destination_config.source_account_id }
        Action    = "events:PutEvents"
        Resource  = aws_cloudwatch_event_bus.destination.arn
      }
    ]
  })
}

locals {
  targets_indexed = {
    for idx, t in var.webhook_relay_destination_config.targets : idx => t
  }
}

resource "aws_cloudwatch_event_rule" "receive" {
  for_each       = local.targets_indexed
  name           = "${var.webhook_relay_destination_config.name_prefix}-receive-${each.key}"
  description    = "Webhook relay target ${each.key}"
  event_bus_name = aws_cloudwatch_event_bus.destination.name
  event_pattern  = each.value.event_pattern
  tags           = local.all_security_tags
  tags_all       = local.all_security_tags
}

resource "aws_cloudwatch_event_target" "lambda" {
  for_each       = aws_cloudwatch_event_rule.receive
  rule           = each.value.name
  event_bus_name = each.value.event_bus_name
  arn            = local.targets_indexed[each.key].lambda_function_arn
}

resource "aws_lambda_permission" "eventbridge_invoke" {
  for_each      = aws_cloudwatch_event_rule.receive
  action        = "lambda:InvokeFunction"
  function_name = local.targets_indexed[each.key].lambda_function_arn
  principal     = "events.amazonaws.com"
  source_arn    = each.value.arn
}
