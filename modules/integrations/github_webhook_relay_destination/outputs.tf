output "role_arn" {
  value       = aws_iam_role.reader.arn
  description = "Local role ARN."
}

output "webhook" {
  value       = try(data.external.fetch_secret_value[0].result.secret_value, null)
  sensitive   = true
  description = "Webhook relay and secret fetched from source account."
}
