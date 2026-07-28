run "runner_logs_ingestion_dashboard_interface_contract" {
  command = plan

  module {
    source = "../../../../../tests/tofu/module_interface_contract"
  }

  variables {
    module_path = "."
    expected_input_variables = [
      "dashboard_group",
      "dynamic_variables",
      "lambda_dimension_filter",
    ]
    expected_output_values = []
    expected_interface_literals = [
      "variable \"dashboard_group\"",
      "variable \"dynamic_variables\"",
      "variable \"lambda_dimension_filter\"",
      "description = \"Canonical AWS Lambda resource-level SignalFlow filter.\"",
      "property               = string",
      "values_suggested       = list(string)",
      "restricted_suggestions = bool",
    ]
  }

  assert {
    condition     = length(output.missing_input_variables) == 0 && length(output.unexpected_input_variables) == 0
    error_message = "Runner-log ingestion dashboard input contract is not exact."
  }
}
