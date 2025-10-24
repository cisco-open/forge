module "github_webhook_relay" {
  count  = var.github_webhook_relay.enabled ? 1 : 0
  source = "./github_webhook_relay"

  providers = {
    aws = aws
  }

  prefix                    = var.deployment_config.prefix
  secret_prefix             = "/cicd/common/${var.tenant.name}/${var.deployment_config.secret_suffix}"
  logging_retention_in_days = var.logging_retention_in_days
  tags                      = local.all_security_tags

  github_webhook_relay = var.github_webhook_relay
}
