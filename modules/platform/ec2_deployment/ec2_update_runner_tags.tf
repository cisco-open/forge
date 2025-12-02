module "ec2_update_runner_tags" {
  source = "./ec2_update_runner_tags"

  providers = {
    aws = aws
  }

  prefix                    = var.runner_configs.prefix
  logging_retention_in_days = var.runner_configs.logging_retention_in_days
  log_level                 = var.runner_configs.log_level
  tags                      = var.tenant_configs.tags

  event_bus = module.runners.webhook.eventbridge.event_bus.name
}
