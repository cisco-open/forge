run "s3_control_plane_dashboard_interface_contract" {
  command = plan

  module {
    source = "../../../../../tests/tofu/module_interface_contract"
  }

  variables {
    module_path              = "."
    expected_input_variables = ["dashboard_group", "dynamic_variables"]
    expected_output_values   = []
    expected_interface_literals = [
      "variable \"dashboard_group\"",
      "variable \"dynamic_variables\"",
    ]
  }

  assert {
    condition     = length(output.missing_input_variables) == 0 && length(output.unexpected_input_variables) == 0
    error_message = "Control-plane S3 dashboard input contract is not exact."
  }
}
