
output "splunk_integration_name" {
  description = "The name of the Splunk integration CloudFormation stack."
  value       = local.name
}

output "splunk_integration_template_url" {
  description = "The URL of the CloudFormation template for the Splunk integration."
  value       = local.template_url
}

output "splunk_integration_tags" {
  description = "The tags applied to the Splunk integration CloudFormation stack."
  value       = local.tags
}

output "splunk_integration_tags_all" {
  description = "All tags applied to the Splunk integration CloudFormation stack, including inherited tags."
  value       = local.tags_all
}
