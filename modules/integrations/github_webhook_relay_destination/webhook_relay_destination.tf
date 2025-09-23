module "webhook_relay_destination" {
  source = "../webhook_relay/destination"

  # Your module inputs
  name_prefix                = var.webhook_relay_destination_config.name_prefix
  tags                       = local.all_security_tags
  destination_event_bus_name = var.webhook_relay_destination_config.destination_event_bus_name
  source_account_id          = var.webhook_relay_destination_config.source_account_id
  targets                    = var.webhook_relay_destination_config.targets
}
