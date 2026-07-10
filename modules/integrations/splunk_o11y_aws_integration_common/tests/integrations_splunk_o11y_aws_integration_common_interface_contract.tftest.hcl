run "integrations_splunk_o11y_aws_integration_common_interface_contract" {
  command = plan

  module {
    source = "../../../tests/tofu/module_interface_contract"
  }

  variables {
    module_path = "."
    expected_input_variables = [
      "aws_profile",
      "aws_region",
      "default_tags",
      "integration_name",
      "integration_regions",
      "splunk_api_url",
      "splunk_organization_id",
      "tags",
    ]
    expected_output_values = [
      "iam_role_splunk_integration",
    ]
    expected_interface_literals = [
      "variable \"aws_profile\"",
      "type        = string",
      "description = \"AWS profile to use.\"",
      "variable \"aws_region\"",
      "description = \"Default AWS region.\"",
      "variable \"default_tags\"",
      "type        = map(string)",
      "description = \"A map of tags to apply to resources.\"",
      "variable \"integration_name\"",
      "description = \"Name of the integration.\"",
      "variable \"integration_regions\"",
      "type        = list(string)",
      "description = \"List of regions for the integration.\"",
      "variable \"splunk_api_url\"",
      "description = \"URL for plunk Observability Cloud API.\"",
      "variable \"splunk_organization_id\"",
      "description = \"organization ID for Splunk Observability Cloud.\"",
      "variable \"tags\"",
      "output \"iam_role_splunk_integration\"",
      "value = aws_iam_role.splunk_integration.arn",
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
      output.expected_input_variable_count == 8
      && output.expected_output_value_count == 1
      && output.expected_interface_literal_count == 20
    )
    error_message = "Interface contract counts must remain pinned for inputs, outputs, and source literals."
  }
}
