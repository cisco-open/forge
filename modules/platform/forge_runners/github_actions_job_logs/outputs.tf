output "s3_bucket_arn" {
  description = "The ARN of the S3 bucket where GitHub Actions job logs are stored."
  value       = aws_s3_bucket.gh_logs.arn
}

output "internal_s3_reader_role_arn" {
  description = "The ARN of the IAM role used for reading from the S3 bucket."
  value       = aws_iam_role.internal_s3_reader.arn
}
