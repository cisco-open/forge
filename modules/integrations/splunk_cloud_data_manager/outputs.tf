output "splunk_cloud_input_cloudwatch_logs_json" {
  description = "The Splunk Cloud input map."
  value       = var.cloudwatch_log_groups_config.enabled ? local.splunk_cloud_input_cloudwatch_json : ""
}

output "splunk_cloud_input_security_metadata_json" {
  description = "The Splunk Cloud input map for security metadata."
  value       = var.security_metadata_config.enabled ? local.splunk_cloud_input_security_metadata_json : ""
}

output "splunk_cloud_input_custom_logs_json" {
  description = "The Splunk Cloud input map for custom logs."
  value       = var.custom_cloudwatch_log_groups_config.enabled ? local.splunk_cloud_input_custom_logs_json : ""
}
