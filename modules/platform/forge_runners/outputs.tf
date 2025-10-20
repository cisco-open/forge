output "forge_core" {
  description = "Core tenant-level metadata (non-sensitive)."
  value = {
    tenant            = var.tenant
    runner_group_name = var.runner_group_name
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
      runners_arn_map    = try(module.arc_runners.arc_runners_arn_map, {})
      subnet_cidr_blocks = try(module.arc_runners.subnet_cidr_blocks, [])
    }
  }
}

output "forge_webhook_relay" {
  description = "Webhook relay integration outputs."
  value = {
    source_secret_arn      = try(aws_secretsmanager_secret.github_webhook_relay[0].arn, null)
    source_secret_role_arn = try(aws_iam_role.secret_reader[0].arn, null)
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
    installation_id  = try(data.aws_secretsmanager_secret_version.data_cicd_secrets["${local.cicd_secrets_prefix}github_actions_runners_app_installation_id"].secret_string, null)
    name             = try(data.aws_secretsmanager_secret_version.data_cicd_secrets["${local.cicd_secrets_prefix}github_actions_runners_app_name"].secret_string, null)
  }
  sensitive = true
}
