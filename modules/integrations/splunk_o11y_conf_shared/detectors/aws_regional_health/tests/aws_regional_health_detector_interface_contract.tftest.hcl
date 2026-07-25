run "aws_regional_health_detector_interface_contract" {
  command = plan

  module {
    source = "../../../../../tests/tofu/module_interface_contract"
  }

  variables {
    module_path = "."
    expected_input_variables = [
      "detector_name_prefix",
      "detector_notifications",
      "dynamic_variables",
      "team",
    ]
    expected_output_values = [
      "detector_id",
    ]
    expected_interface_literals = [
      "variable \"detector_notifications\"",
      "variable \"detector_name_prefix\"",
      "variable \"dynamic_variables\"",
      "variable \"team\"",
      "property               = string",
      "alias                  = string",
      "description            = string",
      "values                 = list(string)",
      "value_required         = bool",
      "values_suggested       = list(string)",
      "restricted_suggestions = bool",
      "output \"detector_id\"",
      "description = \"AWS regional platform detector ID for linking queue-health charts.\"",
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
    condition     = length(output.missing_interface_literals) == 0
    error_message = "Interface contract is missing expected source lines: ${join(", ", output.missing_interface_literals)}"
  }

  assert {
    condition = (
      output.expected_input_variable_count == 4
      && output.expected_output_value_count == 1
      && output.expected_interface_literal_count == 13
    )
    error_message = "Interface contract counts must remain pinned."
  }
}
