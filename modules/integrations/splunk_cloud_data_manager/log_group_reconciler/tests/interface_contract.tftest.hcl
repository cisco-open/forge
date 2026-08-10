run "integrations_splunk_cloud_data_manager_log_group_reconciler_interface_contract" {
  command = plan

  module {
    source = "../../../../tests/tofu/module_interface_contract"
  }

  variables {
    module_path = "."
    expected_input_variables = [
      "region",
      "tags",
    ]
    expected_output_values = [
      "lambda_function_name",
    ]
    expected_interface_literals = [
      "variable \"region\"",
      "type        = string",
      "description = \"AWS region where the reconciler and Splunk Data Manager stacks run.\"",
      "variable \"tags\"",
      "type        = map(string)",
      "description = \"Tags to apply to reconciler resources.\"",
      "output \"lambda_function_name\"",
      "description = \"Name of the regional Splunk Data Manager log-group reconciler Lambda.\"",
      "value       = module.log_group_reconciler.lambda_function_name",
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
      output.expected_input_variable_count == 2
      && output.expected_output_value_count == 1
      && output.expected_interface_literal_count == 9
    )
    error_message = "Interface contract counts must remain pinned for inputs, outputs, and source literals."
  }
}
