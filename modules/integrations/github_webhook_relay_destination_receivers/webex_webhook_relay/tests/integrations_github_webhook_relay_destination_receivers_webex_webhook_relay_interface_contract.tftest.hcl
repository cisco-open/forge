run "integrations_github_webhook_relay_destination_receivers_webex_webhook_relay_interface_contract" {
  command = plan

  module {
    source = "../../../../tests/tofu/module_interface_contract"
  }

  variables {
    module_path = "."
    expected_input_variables = [
      "aws_region",
      "default_tags",
      "log_level",
      "logging_retention_in_days",
      "tags",
    ]
    expected_output_values = [
      "lambda_function_arn",
    ]
    expected_interface_literals = [
      "variable \"aws_region\"",
      "description = \"Default AWS region.\"",
      "type        = string",
      "variable \"default_tags\"",
      "type        = map(string)",
      "description = \"A map of tags to apply to resources.\"",
      "variable \"log_level\"",
      "description = \"Log level for application logging (e.g., INFO, DEBUG, WARN, ERROR)\"",
      "default     = \"INFO\"",
      "variable \"logging_retention_in_days\"",
      "type        = number",
      "description = \"Number of days to retain logs in CloudWatch.\"",
      "default     = 3",
      "variable \"tags\"",
      "output \"lambda_function_arn\"",
      "value = module.webex.lambda_function_arn",
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
      output.expected_input_variable_count == 5
      && output.expected_output_value_count == 1
      && output.expected_interface_literal_count == 16
    )
    error_message = "Interface contract counts must remain pinned for inputs, outputs, and source literals."
  }
}
