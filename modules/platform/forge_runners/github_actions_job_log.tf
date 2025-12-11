module "github_actions_job_logs" {
  count  = length(var.ec2_deployment_specs.runner_specs) > 0 ? 1 : 0
  source = "./github_actions_job_logs"

  providers = {
    aws = aws
  }

  prefix = var.deployment_config.deployment_prefix
  github_app = {
    key_base64_ssm = {
      arn = aws_ssm_parameter.github_app_key.arn
    }
    id_ssm = {
      arn = aws_ssm_parameter.github_app_id.arn
    }
    installation_id_ssm = {
      arn = aws_ssm_parameter.github_app_installation_id.arn
    }
  }
  shared_role_arns          = var.deployment_config.tenant.github_logs_reader_role_arns
  logging_retention_in_days = var.logging_retention_in_days
  log_level                 = var.log_level
  tags                      = local.all_security_tags
  event_bus_name            = module.ec2_runners[0].event_bus_name
  ghes_url                  = var.deployment_config.github.ghes_url

}
