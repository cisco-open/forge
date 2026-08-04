output "s3_bucket_arn" {
  description = "The ARN of the S3 bucket where GitHub Actions job logs are stored."
  value       = aws_s3_bucket.gh_logs.arn
}

output "s3_bucket_kms_key_arn" {
  description = "The ARN of the KMS key used to encrypt GitHub Actions job logs."
  value       = aws_kms_key.gh_logs.arn
}

output "s3_notification_queue_arn" {
  description = "The ARN of the SQS queue receiving GitHub Actions job log S3 notifications."
  value       = aws_sqs_queue.s3_notifications.arn
}

output "s3_notification_queue_url" {
  description = "The URL of the SQS queue receiving GitHub Actions job log S3 notifications."
  value       = aws_sqs_queue.s3_notifications.url
}

output "internal_s3_reader_role_arn" {
  description = "The ARN of the IAM role used for reading from the S3 bucket."
  value       = aws_iam_role.internal_s3_reader.arn
}
