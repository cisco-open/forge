run "lambda_control_plane_dashboard_interface_contract" {
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
      "variable \"detector_id\"",
      "variable \"dynamic_variables\"",
      "property               = string",
      "values_suggested       = list(string)",
      "restricted_suggestions = bool",
    ]
  }

  assert {
    condition     = length(output.missing_input_variables) == 0 && length(output.unexpected_input_variables) == 0
    error_message = "Lambda control-plane dashboard input contract is not exact."
  }
}
