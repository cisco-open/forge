output "configuration_recorder_name" {
  description = "Name of the enabled AWS Config configuration recorder."
  value       = aws_config_configuration_recorder.dedicated_hosts.name
}

output "delivery_bucket_name" {
  description = "Name of the S3 bucket receiving AWS Config snapshots and history."
  value       = aws_s3_bucket.config_delivery.bucket
}

output "recorded_resource_types" {
  description = "AWS resource types recorded for Dedicated Host configuration history."
  value       = local.dedicated_host_resource_types
}
