run "aws_regional_health_dashboard_interface_contract" {
  command = plan

  module {
    source = "../../../../../tests/tofu/module_interface_contract"
  }

  variables {
    module_path = "."
    expected_input_variables = [
      "dashboard_group",
      "detector_id",
      "dynamic_variables",
    ]
    expected_output_values = []
    expected_interface_literals = [
      "variable \"dashboard_group\"",
      "description = \"Splunk Observability dashboard group ID.\"",
      "variable \"dynamic_variables\"",
      "property               = string",
      "values_suggested       = list(string)",
      "restricted_suggestions = bool",
      "variable \"detector_id\"",
      "description = \"AWS regional platform detector ID linked to queue-health charts.\"",
    ]
  }

  assert {
    condition     = length(output.missing_input_variables) == 0 && length(output.unexpected_input_variables) == 0
    error_message = "Regional AWS dashboard input contract is not exact."
  }

  assert {
    condition     = length(output.missing_output_values) == 0 && length(output.unexpected_output_values) == 0
    error_message = "Regional AWS dashboard must not expose unexpected outputs."
  }

  assert {
    condition     = length(output.missing_interface_literals) == 0
    error_message = "Regional AWS dashboard interface is missing expected source literals."
  }
}
