module "github_webhook_relay" {
  count  = var.github_webhook_relay.enabled ? 1 : 0
  source = "./github_webhook_relay"

  providers = {
    aws = aws
  }

  prefix                    = var.deployment_config.deployment_prefix
  secret_prefix             = "/cicd/common/${var.deployment_config.tenant.name}/${var.deployment_config.secret_suffix}"
  logging_retention_in_days = var.logging_retention_in_days
  log_level                 = var.log_level
  tags                      = local.all_security_tags

  github_webhook_relay = var.github_webhook_relay

  depends_on = [data.aws_secretsmanager_secret_version.data_cicd_secrets]
}
