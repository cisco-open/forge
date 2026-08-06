run "helpers_dedicated_mac_hosts_interface_contract" {
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
      "host_groups",
      "tags",
    ]
    expected_output_values = [
      "license_specification_arn",
      "resource_group_arns",
    ]
    expected_interface_literals = [
      "variable \"aws_profile\"",
      "variable \"aws_region\"",
      "variable \"default_tags\"",
      "variable \"tags\"",
      "variable \"host_groups\"",
      "host_instance_type = string",
      "availability_zone = string",
      "error_message = \"Each host group must have a unique name.\"",
      "output \"resource_group_arns\"",
      "output \"license_specification_arn\"",
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
