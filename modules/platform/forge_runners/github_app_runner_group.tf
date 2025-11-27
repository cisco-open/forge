module "github_app_runner_group" {
  source = "./github_app_runner_group"

  providers = {
    aws = aws
  }

  prefix                    = var.deployment_config.prefix
  secrets_prefix            = local.cicd_secrets_prefix
  logging_retention_in_days = var.logging_retention_in_days
  log_level                 = var.log_level
  tags                      = local.all_security_tags
  github_api                = local.github_api
  ghes_org                  = var.ghes_org
  runner_group_name         = var.runner_group_name
  repository_selection      = var.repository_selection

  depends_on = [data.aws_secretsmanager_secret_version.data_cicd_secrets]
}
