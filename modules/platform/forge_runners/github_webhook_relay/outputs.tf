output "source_secret_arn" {
  description = "ARN of the GitHub webhook relay secret"
  value       = aws_secretsmanager_secret.github_webhook_relay.arn
}

output "source_secret_role_arn" {
  description = "ARN of IAM role permitted to read/decrypt the webhook relay secret"
  value       = aws_iam_role.secret_reader.arn
}

output "source_secret_region" {
  description = "AWS region the secret resides in"
  value       = data.aws_region.current.region
}
