output "s3_bucket_arn" {
  description = "The ARN of the S3 bucket where GitHub Actions job logs are stored."
  value       = aws_s3_bucket.gh_logs.arn
}

output "s3_bucket_kms_key_arn" {
  description = "The ARN of the KMS key used to encrypt GitHub Actions job logs."
  value       = aws_kms_key.gh_logs.arn
}

output "sqs" {
  description = "The SQS queue receiving GitHub Actions job log S3 notifications."
  value = {
    arn = aws_sqs_queue.s3_notifications.arn
    url = aws_sqs_queue.s3_notifications.url
  }
}

output "internal_s3_reader_role_arn" {
  description = "The ARN of the IAM role used for reading from the S3 bucket."
  value       = aws_iam_role.internal_s3_reader.arn
}
