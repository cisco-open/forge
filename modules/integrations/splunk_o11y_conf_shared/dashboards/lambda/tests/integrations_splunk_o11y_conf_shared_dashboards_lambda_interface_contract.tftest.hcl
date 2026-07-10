run "integrations_splunk_o11y_conf_shared_dashboards_lambda_interface_contract" {
  command = plan

  module {
    source = "../../../../../tests/tofu/module_interface_contract"
  }

  variables {
    module_path = "."
    expected_input_variables = [
      "dashboard_group",
      "dynamic_variables",
      "tenant_names",
    ]
    expected_output_values = []
    expected_interface_literals = [
      "variable \"dashboard_group\"",
      "description = \"Dashboard group name for organizing dashboards.\"",
      "type        = string",
      "variable \"dynamic_variables\"",
      "description = \"Additional dynamic variable definitions for the dashboard.\"",
      "type = list(object({",
      "property               = string",
      "alias                  = string",
      "description            = string",
      "values                 = list(string)",
      "value_required         = bool",
      "values_suggested       = list(string)",
      "restricted_suggestions = bool",
      "}))",
      "default = []",
      "variable \"tenant_names\"",
      "description = \"List of tenant names used for the dashboard.\"",
      "type        = list(string)",
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
      output.expected_input_variable_count == 3
      && output.expected_output_value_count == 0
      && output.expected_interface_literal_count == 18
    )
    error_message = "Interface contract counts must remain pinned for inputs, outputs, and source literals."
  }
}
