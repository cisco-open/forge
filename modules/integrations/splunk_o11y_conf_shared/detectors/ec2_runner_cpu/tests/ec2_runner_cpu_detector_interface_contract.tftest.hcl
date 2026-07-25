run "ec2_runner_cpu_detector_interface_contract" {
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
      "tenant_names",
    ]
    expected_output_values = ["detector_id"]
    expected_interface_literals = [
      "variable \"detector_name_prefix\"",
      "variable \"detector_notifications\"",
      "variable \"dynamic_variables\"",
      "variable \"team\"",
      "variable \"tenant_names\"",
      "output \"detector_id\"",
      "value       = signalfx_detector.ec2_runner_cpu.id",
    ]
  }

  assert {
    condition = (
      length(output.missing_input_variables) == 0
      && length(output.unexpected_input_variables) == 0
      && length(output.missing_output_values) == 0
      && length(output.unexpected_output_values) == 0
      && length(output.missing_interface_literals) == 0
    )
    error_message = "The EC2 runner CPU detector interface must remain explicit and complete."
  }
}
