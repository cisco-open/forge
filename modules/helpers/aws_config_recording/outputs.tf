output "configuration_recorder_name" {
  description = "Name of the enabled AWS Config configuration recorder."
  value       = aws_config_configuration_recorder.this.name
}

output "delivery_bucket_name" {
  description = "Name of the S3 bucket receiving AWS Config snapshots and history."
  value       = var.delivery_bucket_name
}

output "recorded_resource_types" {
  description = "AWS resource types recorded by AWS Config."
  value       = var.recorded_resource_types
}
