run "platform_forge_runners_redrive_deadletter_interface_contract" {
  command = plan

  module {
    source = "../../../../tests/tofu/module_interface_contract"
  }

  variables {
    module_path = "."
    expected_input_variables = [
      "log_level",
      "logging_retention_in_days",
      "prefix",
      "sqs_map",
      "tags",
    ]
    expected_output_values = []
    expected_interface_literals = [
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
      "variable \"sqs_map\"",
      "description = \"Map of runner SQS queue names.\"",
      "type = map(object({",
      "main = string",
      "dlq  = string",
      "}))",
      "variable \"tags\"",
      "description = \"Tags to apply to created resources.\"",
      "type        = map(string)",
      "default     = {}",
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
      && output.expected_output_value_count == 0
      && output.expected_interface_literal_count == 20
    )
    error_message = "Interface contract counts must remain pinned for inputs, outputs, and source literals."
  }
}
