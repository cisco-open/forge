run "dependency_probes_interface_contract" {
  command = plan

  module {
    source = "../../../../../tests/tofu/module_interface_contract"
  }

  variables {
    module_path = "."
    expected_input_variables = [
      "detector_config",
      "detector_name_prefix",
      "detector_notifications",
      "team",
      "tenant_names",
    ]
    expected_output_values = [
      "detector_ids",
    ]
    expected_interface_literals = [
      "variable \"detector_notifications\"",
      "variable \"detector_name_prefix\"",
      "variable \"team\"",
      "variable \"tenant_names\"",
      "variable \"detector_config\"",
      "failure_duration                   = string",
      "no_data_duration                   = string",
      "no_data_fill_duration              = string",
      "rate_limit_duration                = string",
      "rate_limit_remaining_pct_threshold = number",
      "output \"detector_ids\"",
      "description = \"Dependency detector IDs keyed by tenant for linking dashboard charts.\"",
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
      output.expected_input_variable_count == 5
      && output.expected_output_value_count == 1
      && output.expected_interface_literal_count == 12
    )
    error_message = "Interface contract counts must remain pinned."
  }
}
