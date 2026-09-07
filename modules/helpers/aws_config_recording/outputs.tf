output "configuration_recorder_name" {
  description = "Name of the enabled AWS Config configuration recorder."
  value       = aws_config_configuration_recorder.this.name
}

output "delivery_bucket_arn" {
  description = "ARN of the S3 bucket receiving AWS Config snapshots and history."
  value = local.create_delivery_resources ? (
    aws_s3_bucket.config_delivery[0].arn
  ) : "arn:${data.aws_partition.current.partition}:s3:::${local.delivery_bucket_name}"
}

output "delivery_bucket_name" {
  description = "Name of the S3 bucket receiving AWS Config snapshots and history."
  value       = local.delivery_bucket_name
}

output "recorded_resource_types" {
  description = "AWS resource types recorded by AWS Config."
  value       = var.recorded_resource_types
}

output "sqs" {
  description = "SQS queue receiving managed AWS Config S3 object notifications, or null when an external bucket is used."
  value = local.create_delivery_resources ? {
    arn                   = aws_sqs_queue.config_events[0].arn
    dead_letter_queue_arn = aws_sqs_queue.config_events_dlq[0].arn
    url                   = aws_sqs_queue.config_events[0].url
  } : null
}

output "splunk_s3_logs" {
  description = "Managed AWS Config S3 and SQS resources for a Splunk Data Manager s3-custom-logs input, or null when an external bucket is used."
  value = local.create_delivery_resources ? {
    bucket_arn         = aws_s3_bucket.config_delivery[0].arn
    bucket_kms_key_arn = null
    sqs = {
      arn                   = aws_sqs_queue.config_events[0].arn
      dead_letter_queue_arn = aws_sqs_queue.config_events_dlq[0].arn
      url                   = aws_sqs_queue.config_events[0].url
    }
  } : null
}
