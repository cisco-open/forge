output "role_arn" {
  value       = module.webhook_relay_destination.role_arn
  description = "Local role ARN."
}

output "webhook" {
  value       = module.webhook_relay_destination.webhook
  sensitive   = true
  description = "Webhook relay and secret fetched from source account."
}
