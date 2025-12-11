module "github_app_runner_group" {
  source = "./github_app_runner_group"

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
  logging_retention_in_days = var.logging_retention_in_days
  log_level                 = var.log_level
  tags                      = local.all_security_tags
  github_api                = local.github_api
  ghes_org                  = var.deployment_config.github.ghes_org
  runner_group_name         = var.deployment_config.github.runner_group_name
  repository_selection      = var.deployment_config.github.repository_selection

}
