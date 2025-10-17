# Needed for the GitHub App to issue callbacks.
output "webhook_endpoint" {
  value = try(module.ec2_runners[0].webhook_endpoint, null)
}

output "webhook_secret" {
  value     = try(random_id.random[0].hex, null)
  sensitive = true
}

output "ec2_runners_arn_map" {
  value = try(module.ec2_runners[0].ec2_runners_arn_map, {})
}

output "ec2_runners_ami_name_map" {
  value = try(module.ec2_runners[0].ec2_runners_ami_name_map, {})
}

output "ec2_subnet_cidr_blocks" {
  value = try(module.ec2_runners[0].subnet_cidr_blocks, [])
}

output "arc_runners_arn_map" {
  value = try(module.arc_runners.arc_runners_arn_map, {})
}

output "arc_subnet_cidr_blocks" {
  value = try(module.arc_runners.subnet_cidr_blocks, [])
}

output "github_app_installation" {
  value     = local.github_app_installation
  sensitive = true
}

output "runner_group_name" {
  value = var.runner_group_name
}

output "tenant" {
  value = var.tenant
}

output "github_webhook_relay_source_secret" {
  value     = try(random_id.github_webhook_relay_source_secret[0].hex, null)
  sensitive = true
}

output "github_webhook_relay_source_webhook_endpoint" {
  description = "The webhook endpoint for GitHub webhook relay."
  value       = try(module.github_webhook_relay_source[0].webhook_endpoint, null)
}

output "github_webhook_relay_source_secret_arn" {
  value = try(aws_secretsmanager_secret.github_webhook_relay[0].arn, null)
}

output "github_webhook_relay_source_secret_role_arn" {
  value = try(aws_iam_role.secret_reader[0].id, null)
}

output "github_actions_job_logs" {
  description = "Map containing GitHub Actions job logs resources (bucket_arn, internal_reader_role_arn)."
  value = {
    bucket_arn               = try(module.github_actions_job_logs[0].s3_bucket_arn, null)
    internal_reader_role_arn = try(module.github_actions_job_logs[0].internal_s3_reader_role_arn, null)
  }
}
