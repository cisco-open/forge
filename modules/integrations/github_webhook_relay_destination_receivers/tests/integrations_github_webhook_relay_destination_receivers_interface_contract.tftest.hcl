run "integrations_github_webhook_relay_destination_receivers_interface_contract" {
  command = plan

  module {
    source = "../../../tests/tofu/module_interface_contract"
  }

  variables {
    module_path = "."
    expected_input_variables = [
      "aws_profile",
      "aws_region",
      "default_tags",
      "enable_webex_webhook_relay",
      "log_level",
      "logging_retention_in_days",
      "reader_config",
      "reader_role_name",
      "tags",
      "webhook_relay_destination_config",
    ]
    expected_output_values = [
      "role_arn",
      "webhook",
    ]
    expected_interface_literals = [
      "variable \"aws_profile\"",
      "description = \"AWS profile to use.\"",
      "type        = string",
      "variable \"aws_region\"",
      "description = \"Default AWS region.\"",
      "variable \"default_tags\"",
      "type        = map(string)",
      "description = \"A map of tags to apply to resources.\"",
      "variable \"enable_webex_webhook_relay\"",
      "type        = bool",
      "description = \"Enable Webex webhook relay.\"",
      "variable \"log_level\"",
      "description = \"Log level for application logging (e.g., INFO, DEBUG, WARN, ERROR)\"",
      "default     = \"INFO\"",
      "variable \"logging_retention_in_days\"",
      "description = \"Number of days to retain logs.\"",
      "type        = number",
      "default     = 3",
      "variable \"reader_config\"",
      "description = \"Configuration for the reader to fetch secrets.\"",
      "type = object({",
      "enable_secret_fetch    = bool",
      "source_secret_role_arn = string",
      "source_secret_arn      = string",
      "source_secret_region   = string",
      "variable \"reader_role_name\"",
      "description = \"IAM role name used by the destination reader to fetch secrets.\"",
      "default     = \"forge-github-webhook-relay-secret-reader\"",
      "variable \"tags\"",
      "variable \"webhook_relay_destination_config\"",
      "description = \"Configuration for webhook relay destination.\"",
      "name_prefix                = string",
      "destination_event_bus_name = string",
      "source_account_id          = string",
      "output \"role_arn\"",
      "value       = module.webhook_relay_destination.role_arn",
      "description = \"Local role ARN.\"",
      "output \"webhook\"",
      "value       = module.webhook_relay_destination.webhook",
      "sensitive   = true",
      "description = \"Webhook relay and secret fetched from source account.\"",
    ]
  }

  assert {
    condition     = length(output.missing_input_variables) == 0
    error_message = "Interface contract is missing input variables: ${join(", ", output.missing_input_variables)}"
  }

  assert {
    condition     = length(output.unexpected_input_variables) == 0
    error_message = "Interface contract has unexpected input variables: ${join(", ", output.unexpected_input_variables)}"
  }

  assert {
    condition     = length(output.missing_output_values) == 0
    error_message = "Interface contract is missing outputs: ${join(", ", output.missing_output_values)}"
  }

  assert {
    condition     = length(output.unexpected_output_values) == 0
    error_message = "Interface contract has unexpected outputs: ${join(", ", output.unexpected_output_values)}"
  }

  assert {
    condition     = length(output.missing_interface_literals) == 0
    error_message = "Interface contract is missing expected variable/output source lines: ${join(", ", output.missing_interface_literals)}"
  }

  assert {
    condition = (
      output.expected_input_variable_count == 10
      && output.expected_output_value_count == 2
      && output.expected_interface_literal_count == 41
    )
    error_message = "Interface contract counts must remain pinned for inputs, outputs, and source literals."
  }
}
