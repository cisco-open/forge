output "api_endpoint" {
  description = "Base HTTP API endpoint for the Splunk alert webhook receiver."
  value       = aws_apigatewayv2_api.splunk.api_endpoint
}

output "splunk_webhook_url" {
  description = "Full Splunk webhook URL, including the shared path token."
  value       = local.splunk_webhook_url
  sensitive   = true
}

output "receiver_lambda_function_arn" {
  description = "Splunk webhook receiver Lambda ARN."
  value       = module.dispatcher.lambda_function_arn
}

output "api_log_group_name" {
  description = "CloudWatch log group containing API Gateway HTTP API access logs."
  value       = aws_cloudwatch_log_group.api.name
}

output "receiver_lambda_log_group_name" {
  description = "CloudWatch log group containing Splunk webhook receiver Lambda logs."
  value       = aws_cloudwatch_log_group.dispatcher.name
}

output "worker_lambda_function_arn" {
  description = "GitHub App redelivery worker Lambda ARN."
  value       = module.worker.lambda_function_arn
}

output "worker_lambda_log_group_name" {
  description = "CloudWatch log group containing GitHub App redelivery worker Lambda logs."
  value       = aws_cloudwatch_log_group.worker.name
}

output "dedupe_table_name" {
  description = "DynamoDB table used to suppress duplicate dispatches."
  value       = aws_dynamodb_table.dedupe.name
}

output "saved_search_name" {
  description = "Splunk saved search alert name."
  value       = var.splunk_alert.name
}
