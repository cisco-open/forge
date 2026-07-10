run "integrations_splunk_cloud_data_manager_data_input_interface_contract" {
  command = plan

  module {
    source = "../../../../tests/tofu/module_interface_contract"
  }

  variables {
    module_path = "."
    expected_input_variables = [
      "cloudformation_s3_config",
      "splunk_cloud",
      "splunk_cloud_input_json",
      "tags_all",
    ]
    expected_output_values = [
      "splunk_integration_name",
      "splunk_integration_tags",
      "splunk_integration_tags_all",
      "splunk_integration_template_url",
    ]
    expected_interface_literals = [
      "variable \"cloudformation_s3_config\"",
      "type = object({",
      "bucket = string",
      "key    = string",
      "description = \"S3 bucket for CloudFormation templates.\"",
      "variable \"splunk_cloud\"",
      "type        = string",
      "description = \"Splunk Cloud endpoint.\"",
      "variable \"splunk_cloud_input_json\"",
      "description = \"Splunk Cloud input JSON.\"",
      "variable \"tags_all\"",
      "type        = map(string)",
      "description = \"All Tags to apply to resources.\"",
      "output \"splunk_integration_name\"",
      "description = \"The name of the Splunk integration CloudFormation stack.\"",
      "value       = local.name",
      "output \"splunk_integration_tags\"",
      "description = \"The tags applied to the Splunk integration CloudFormation stack.\"",
      "value       = local.tags",
      "output \"splunk_integration_tags_all\"",
      "description = \"All tags applied to the Splunk integration CloudFormation stack, including inherited tags.\"",
      "value       = local.tags_all",
      "output \"splunk_integration_template_url\"",
      "description = \"The URL of the CloudFormation template for the Splunk integration.\"",
      "value       = local.template_url",
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
      output.expected_input_variable_count == 4
      && output.expected_output_value_count == 4
      && output.expected_interface_literal_count == 25
    )
    error_message = "Interface contract counts must remain pinned for inputs, outputs, and source literals."
  }
}
