run "platform_forge_runners_github_webhook_relay_interface_contract" {
  command = plan

  module {
    source = "../../../../tests/tofu/module_interface_contract"
  }

  variables {
    module_path = "."
    expected_input_variables = [
      "github_webhook_relay",
      "log_level",
      "logging_retention_in_days",
      "prefix",
      "secret_prefix",
      "tags",
    ]
    expected_output_values = [
      "source_secret_arn",
      "source_secret_region",
      "source_secret_role_arn",
    ]
    expected_interface_literals = [
      "variable \"github_webhook_relay\"",
      "description = <<-EOT",
      "Configuration for the optional tenant GitHub webhook relay source.",
      "If enabled=true, Forge provisions the API Gateway, validation Lambda, source EventBridge bus, and forwarding rule.",
      "destination_event_bus_name must already exist or be created in the destination account with the destination integration module.",
      "EOT",
      "type = object({",
      "enabled                     = bool",
      "destination_account_id      = optional(string)",
      "destination_event_bus_name  = optional(string)",
      "destination_region          = optional(string)",
      "destination_reader_role_arn = optional(string)",
      "default = {",
      "enabled                     = false",
      "destination_account_id      = \"\"",
      "destination_event_bus_name  = \"\"",
      "destination_region          = \"\"",
      "destination_reader_role_arn = \"\"",
      "variable \"log_level\"",
      "type        = string",
      "description = \"Log level for application logging (e.g., INFO, DEBUG, WARN, ERROR)\"",
      "default     = \"INFO\"",
      "variable \"logging_retention_in_days\"",
      "description = \"Retention in days for CloudWatch Log Group for the Lambdas.\"",
      "type        = number",
      "default     = 30",
      "variable \"prefix\"",
      "description = \"Prefix for all resources\"",
      "variable \"secret_prefix\"",
      "description = \"Prefix for secret\"",
      "variable \"tags\"",
      "description = \"Tags to apply to created resources.\"",
      "type        = map(string)",
      "default     = {}",
      "output \"source_secret_arn\"",
      "description = \"ARN of the GitHub webhook relay secret\"",
      "value       = aws_secretsmanager_secret.github_webhook_relay.arn",
      "output \"source_secret_region\"",
      "description = \"AWS region the secret resides in\"",
      "value       = data.aws_region.current.region",
      "output \"source_secret_role_arn\"",
      "description = \"ARN of IAM role permitted to read/decrypt the webhook relay secret\"",
      "value       = aws_iam_role.secret_reader.arn",
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
      output.expected_input_variable_count == 6
      && output.expected_output_value_count == 3
      && output.expected_interface_literal_count == 43
    )
    error_message = "Interface contract counts must remain pinned for inputs, outputs, and source literals."
  }
}
