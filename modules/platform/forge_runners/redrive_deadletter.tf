locals {
  sqs_prefix_arn = "arn:aws:sqs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}"
}

module "redrive_deadletter" {
  source = "./redrive_deadletter"

  providers = {
    aws = aws
  }

  prefix                    = var.deployment_config.prefix
  logging_retention_in_days = var.logging_retention_in_days
  log_level                 = var.log_level
  tags                      = local.all_security_tags

  sqs_map = merge(
    {
      for key in keys(var.ec2_runner_specs) :
      key => {
        dlq  = "${local.sqs_prefix_arn}:${var.deployment_config.prefix}-${key}-queued-builds_dead_letter"
        main = "${local.sqs_prefix_arn}:${var.deployment_config.prefix}-${key}-queued-builds"
      }
    },
    {
      "gha-job-logs" = {
        dlq  = "${local.sqs_prefix_arn}:${var.deployment_config.prefix}-gha-job-logs-dead-letter"
        main = "${local.sqs_prefix_arn}:${var.deployment_config.prefix}-gha-job-logs"
      }
    },
  )
}
