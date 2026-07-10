run "platform_forge_runners_github_webhook_relay_source_interface_contract" {
  command = plan

  module {
    source = "../../../../../tests/tofu/module_interface_contract"
  }

  variables {
    module_path = "."
    expected_input_variables = [
      "destination_account_id",
      "destination_event_bus_name",
      "destination_region",
      "event_source",
      "log_level",
      "logging_retention_in_days",
      "name_prefix",
      "source_event_bus_name",
      "tags",
      "webhook_secret",
    ]
    expected_output_values = [
      "event_source",
      "source_event_bus_arn",
      "source_event_bus_name",
      "webhook_endpoint",
    ]
    expected_interface_literals = [
      "variable \"destination_account_id\"",
      "description = \"Destination (receiver) AWS account ID\"",
      "type        = string",
      "variable \"destination_event_bus_name\"",
      "description = \"Destination bus name in destination account\"",
      "variable \"destination_region\"",
      "description = \"Destination region (omit for same as source)\"",
      "default     = null",
      "variable \"event_source\"",
      "description = \"EventBridge source field for emitted events\"",
      "default     = \"webhook.relay\"",
      "variable \"log_level\"",
      "description = \"Log level for application logging (e.g., INFO, DEBUG, WARN, ERROR)\"",
      "default     = \"INFO\"",
      "variable \"logging_retention_in_days\"",
      "description = \"Log retention period in days\"",
      "type        = number",
      "default     = 3",
      "variable \"name_prefix\"",
      "description = \"Prefix for created resources\"",
      "default     = \"webhook-relay-source\"",
      "variable \"source_event_bus_name\"",
      "description = \"Name of the source EventBridge bus\"",
      "variable \"tags\"",
      "description = \"Tags to apply to all resources\"",
      "type        = map(string)",
      "default     = {}",
      "variable \"webhook_secret\"",
      "description = \"Secret used to validate incoming webhooks\"",
      "output \"event_source\"",
      "value       = var.event_source",
      "description = \"EventBridge source field value\"",
      "output \"source_event_bus_arn\"",
      "value       = aws_cloudwatch_event_bus.source.arn",
      "description = \"Source bus ARN\"",
      "output \"source_event_bus_name\"",
      "value       = aws_cloudwatch_event_bus.source.name",
      "description = \"Source bus name\"",
      "output \"webhook_endpoint\"",
      "value       = \"$${aws_apigatewayv2_api.webhook.api_endpoint}/$${local.webhook}\"",
      "description = \"Public webhook URL\"",
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
      && output.expected_output_value_count == 4
      && output.expected_interface_literal_count == 41
    )
    error_message = "Interface contract counts must remain pinned for inputs, outputs, and source literals."
  }
}
