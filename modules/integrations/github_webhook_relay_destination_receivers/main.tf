data "aws_caller_identity" "current" {}

locals {
  targets = concat(
    local.webex_target,
  )
}

# Destination module wiring: create bus, rules, and permissions referencing our lambdas
module "webhook_relay_destination" {
  source = "../github_webhook_relay_destination"

  aws_profile = var.aws_profile
  aws_region  = var.aws_region

  reader_config = {
    role_name = "forge-github-webhook-relay-secret-reader"
    role_trust_principals = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
    ]
    enable_secret_fetch    = var.reader_config.enable_secret_fetch
    source_secret_role_arn = var.reader_config.source_secret_role_arn
    source_secret_arn      = var.reader_config.source_secret_arn
    source_secret_region   = var.reader_config.source_secret_region
  }

  webhook_relay_destination_config = {
    name_prefix                = var.webhook_relay_destination_config.name_prefix
    destination_event_bus_name = var.webhook_relay_destination_config.destination_event_bus_name
    source_account_id          = var.webhook_relay_destination_config.source_account_id
    targets                    = local.targets
  }

  tags         = var.tags
  default_tags = var.default_tags
}
