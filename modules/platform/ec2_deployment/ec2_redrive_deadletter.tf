module "ec2_redrive_deadletter" {
  source = "./ec2_redrive_deadletter"

  providers = {
    aws = aws
  }

  prefix                    = var.runner_configs.prefix
  logging_retention_in_days = var.runner_configs.logging_retention_in_days
  log_level                 = var.runner_configs.log_level
  tags                      = var.tenant_configs.tags

  sqs_map = {
    for key in keys(var.runner_configs.runner_specs) :
    key => {
      dlq  = "${var.runner_configs.prefix}-${key}-queued-builds_dead_letter"
      main = "${var.runner_configs.prefix}-${key}-queued-builds"
    }
  }
}
