output "webhook_endpoint" {
  value       = "${aws_apigatewayv2_api.webhook.api_endpoint}/${local.webhook}"
  description = "Public webhook URL"
}

output "source_event_bus_name" {
  value       = aws_cloudwatch_event_bus.source.name
  description = "Source bus name"
}

output "source_event_bus_arn" {
  value       = aws_cloudwatch_event_bus.source.arn
  description = "Source bus ARN"
}

output "event_source" {
  value       = var.event_source
  description = "EventBridge source field value"
}
