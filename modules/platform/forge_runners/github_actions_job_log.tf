module "github_actions_job_logs" {
  count  = length(var.ec2_runner_specs) > 0 ? 1 : 0
  source = "./github_actions_job_logs"

  providers = {
    aws = aws
  }

  prefix                    = var.deployment_config.prefix
  secrets_prefix            = local.cicd_secrets_prefix
  shared_role_arns          = var.tenant.github_logs_reader_role_arns
  logging_retention_in_days = var.logging_retention_in_days
  tags                      = local.all_security_tags
  event_bus_name            = module.ec2_runners[0].event_bus_name
  ghes_url                  = var.ghes_url
}
