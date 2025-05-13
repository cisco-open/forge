# Needed for the GitHub App to issue callbacks.
output "webhook_endpoint" {
  value = module.ec2_runners.webhook_endpoint
}

output "webhook_secret" {
  value     = random_id.random.hex
  sensitive = true
}

output "ec2_runners_arn_map" {
  value = module.ec2_runners.ec2_runners_arn_map
}

output "ec2_runners_ami_name_map" {
  value = module.ec2_runners.ec2_runners_ami_name_map
}

output "ec2_subnet_cidr_blocks" {
  value = module.ec2_runners.subnet_cidr_blocks
}

output "arc_runners_arn_map" {
  value = module.arc_runners.arc_runners_arn_map
}

output "arc_subnet_cidr_blocks" {
  value = module.arc_runners.subnet_cidr_blocks
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
