run "integrations_splunk_cloud_data_manager_sec_meta_ec2_tags_interface_contract" {
  command = plan

  module {
    source = "../../../../tests/tofu/module_interface_contract"
  }

  variables {
    module_path = "."
    expected_input_variables = [
      "environment_variables",
      "region",
      "tags",
    ]
    expected_output_values = []
    expected_interface_literals = [
      "variable \"environment_variables\"",
      "type        = map(string)",
      "description = \"A map of environment variables to set for the Lambda function.\"",
      "variable \"region\"",
      "type        = string",
      "description = \"The AWS region to deploy resources.\"",
      "variable \"tags\"",
      "description = \"Tags to apply to resources.\"",
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
      && output.expected_interface_literal_count == 8
    )
    error_message = "Interface contract counts must remain pinned for inputs, outputs, and source literals."
  }
}
