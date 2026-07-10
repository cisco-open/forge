run "platform_forge_runners_forge_trust_validator_interface_contract" {
  command = plan

  module {
    source = "../../../../tests/tofu/module_interface_contract"
  }

  variables {
    module_path = "."
    expected_input_variables = [
      "forge_iam_roles",
      "iam_propagation_delay_seconds",
      "log_level",
      "logging_retention_in_days",
      "prefix",
      "tags",
      "tenant_iam_roles",
    ]
    expected_output_values = []
    expected_interface_literals = [
      "variable \"forge_iam_roles\"",
      "type        = map(string)",
      "description = \"List of IAM role ARNs for Forge runners.\"",
      "variable \"iam_propagation_delay_seconds\"",
      "type        = number",
      "description = \"Delay between trust policy update and validation to allow IAM/STS propagation.\"",
      "default     = 300",
      "validation {",
      "condition = (",
      "var.iam_propagation_delay_seconds >= 0",
      "&& var.iam_propagation_delay_seconds <= 900",
      ")",
      "error_message = \"iam_propagation_delay_seconds must be between 0 and 900.\"",
      "variable \"log_level\"",
      "type        = string",
      "description = \"Log level for application logging (e.g., INFO, DEBUG, WARN, ERROR)\"",
      "default     = \"INFO\"",
      "variable \"logging_retention_in_days\"",
      "description = \"Retention in days for CloudWatch Log Group for the Lambdas.\"",
      "default     = 30",
      "variable \"prefix\"",
      "description = \"Prefix for all resources\"",
      "variable \"tags\"",
      "description = \"Tags to apply to created resources.\"",
      "default     = {}",
      "variable \"tenant_iam_roles\"",
      "type        = list(string)",
      "description = \"List of IAM role ARNs that the runners will assume to test trust relationships.\"",
      "default     = []",
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
      output.expected_input_variable_count == 7
      && output.expected_output_value_count == 0
      && output.expected_interface_literal_count == 29
    )
    error_message = "Interface contract counts must remain pinned for inputs, outputs, and source literals."
  }
}
