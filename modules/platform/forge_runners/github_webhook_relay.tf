resource "random_id" "github_webhook_relay_source_secret" {
  count       = var.github_webhook_relay.enabled ? 1 : 0
  byte_length = 20
}

module "github_webhook_relay_source" {
  count = var.github_webhook_relay.enabled ? 1 : 0

  source = "../../integrations/webhook-relay/source"

  name_prefix           = "${var.deployment_config.prefix}-github-webhook-relay"
  source_event_bus_name = "${var.deployment_config.prefix}-webhook-relay-source"

  destination_account_id     = var.github_webhook_relay.destination_account_id
  destination_region         = var.github_webhook_relay.destination_region
  destination_event_bus_name = var.github_webhook_relay.destination_event_bus_name

  tags = local.all_security_tags
}
