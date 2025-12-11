output "forge_core" {
  description = "Core tenant-level metadata (non-sensitive)."
  value = {
    tenant            = var.deployment_config.tenant
    runner_group_name = var.deployment_config.github.runner_group_name
  }
}

output "forge_runners" {
  description = "Combined runners output (EC2 + ARC)"
  value = {
    ec2 = {
      runners_arn_map    = try(module.ec2_runners[0].ec2_runners_arn_map, {})
      ami_name_map       = try(module.ec2_runners[0].ec2_runners_ami_name_map, {})
      subnet_cidr_blocks = try(module.ec2_runners[0].subnet_cidr_blocks, [])
    }
    arc = {
      cluster_name       = try(module.arc_runners.arc_cluster_name, {})
      runners_arn_map    = try(module.arc_runners.arc_runners_arn_map, {})
      subnet_cidr_blocks = try(module.arc_runners.subnet_cidr_blocks, [])
    }
  }
}

output "forge_webhook_relay" {
  description = "Webhook relay integration outputs."
  value = {
    source_secret_arn      = try(module.github_webhook_relay[0].source_secret_arn, null)
    source_secret_role_arn = try(module.github_webhook_relay[0].source_secret_role_arn, null)
    source_secret_region   = try(module.github_webhook_relay[0].source_secret_region, null)
  }
}

output "forge_github_actions_job_logs" {
  description = "GitHub Actions job log archival resources."
  value = {
    bucket_arn               = try(module.github_actions_job_logs[0].s3_bucket_arn, null)
    internal_reader_role_arn = try(module.github_actions_job_logs[0].internal_s3_reader_role_arn, null)
  }
}

output "forge_github_app" {
  description = "GitHub App related outputs."
  value = {
    installation_url = local.github_app_installation
    installation_id  = var.deployment_config.github_app.installation_id
    name             = var.deployment_config.github_app.name
  }
  sensitive = true
}
