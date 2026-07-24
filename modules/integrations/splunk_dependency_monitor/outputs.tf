output "lambda_function_arn" {
  description = "ARN of the regional dependency-monitor Lambda."
  value       = module.dependency_monitor.lambda_function_arn
}

output "lambda_log_group_name" {
  description = "CloudWatch log group containing dependency-probe results."
  value       = aws_cloudwatch_log_group.dependency_monitor.name
}
