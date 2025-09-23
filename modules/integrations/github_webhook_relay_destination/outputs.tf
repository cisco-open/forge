output "role_arn" {
  value       = aws_iam_role.reader.arn
  description = "Local role ARN."
}

output "webhook" {
  value       = try(jsondecode(data.aws_secretsmanager_secret_version.target[0].secret_string), null)
  sensitive   = true
  description = "Webhook relay and secret fetched from source account."
}
