output "lambda_function_name" {
  description = "Name of the regional Splunk Data Manager log-group reconciler Lambda."
  value       = module.log_group_reconciler.lambda_function_name
}
