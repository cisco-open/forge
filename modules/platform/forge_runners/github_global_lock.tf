module "github_global_lock" {
  source = "./github_global_lock"

  providers = {
    aws = aws
  }

  prefix                    = var.deployment_config.prefix
  secrets_prefix            = local.cicd_secrets_prefix
  logging_retention_in_days = var.logging_retention_in_days
  tags                      = local.all_security_tags
}
