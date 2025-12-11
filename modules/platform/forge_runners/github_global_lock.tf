module "github_global_lock" {
  source = "./github_global_lock"

  providers = {
    aws = aws
  }

  prefix                    = var.deployment_config.deployment_prefix
  secrets_prefix            = local.cicd_secrets_prefix
  logging_retention_in_days = var.logging_retention_in_days
  log_level                 = var.log_level
  tags                      = local.all_security_tags

  depends_on = [data.aws_secretsmanager_secret_version.data_cicd_secrets]
}
