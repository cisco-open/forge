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
