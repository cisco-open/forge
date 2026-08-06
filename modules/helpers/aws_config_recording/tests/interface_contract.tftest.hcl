run "helpers_aws_config_recording_interface_contract" {
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
      "delivery_bucket_name",
      "delivery_channel_name",
      "iam_role_name",
      "recorded_resource_types",
      "recorder_name",
      "tags",
    ]
    expected_output_values = [
      "configuration_recorder_name",
      "delivery_bucket_name",
      "recorded_resource_types",
    ]
    expected_interface_literals = [
      "variable \"delivery_bucket_name\"",
      "variable \"iam_role_name\"",
      "forge-aws-config-recorder-$${var.aws_region}",
      "variable \"recorded_resource_types\"",
      "variable \"recorder_name\"",
      "variable \"delivery_channel_name\"",
      "output \"configuration_recorder_name\"",
      "output \"delivery_bucket_name\"",
      "output \"recorded_resource_types\"",
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
    error_message = "Interface contract is missing expected source lines: ${join(", ", output.missing_interface_literals)}"
  }
}
