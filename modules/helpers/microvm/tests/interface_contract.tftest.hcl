run "helpers_microvm_interface_contract" {
  command = plan

  module {
    source = "../../../tests/tofu/module_interface_contract"
  }

  variables {
    module_path = "."
    expected_input_variables = [
      "artifact_bucket_name",
      "artifact_retention_days",
      "aws_profile",
      "aws_region",
      "default_tags",
      "ecr_repository_arns",
      "image_name_prefix",
      "network_connectors",
      "tags",
    ]
    expected_output_values = [
      "appregistry_application_arn",
      "artifact_bucket_arn",
      "artifact_bucket_name",
      "artifact_prefix",
      "build_role_arn",
      "connector_arns",
      "image_management_policy_arn",
      "security_group_ids",
      "usage_policy_arn",
    ]
    expected_interface_literals = [
      "variable \"aws_profile\"",
      "variable \"aws_region\"",
      "variable \"default_tags\"",
      "variable \"tags\"",
      "variable \"artifact_bucket_name\"",
      "default     = null",
      "variable \"artifact_retention_days\"",
      "default     = 30",
      "variable \"image_name_prefix\"",
      "IAM namespace prefix reserved for externally published Lambda MicroVM image names.",
      "length(var.image_name_prefix) <= 62",
      "variable \"ecr_repository_arns\"",
      "variable \"network_connectors\"",
      "type = map(object({",
      "network_protocol = optional(string, \"IPv4\")",
      "length(var.network_connectors) > 0",
      "length(connector.subnet_ids) <= 16",
      "output \"artifact_bucket_name\"",
      "output \"artifact_bucket_arn\"",
      "output \"artifact_prefix\"",
      "output \"build_role_arn\"",
      "output \"image_management_policy_arn\"",
      "output \"usage_policy_arn\"",
      "output \"connector_arns\"",
      "output \"security_group_ids\"",
      "output \"appregistry_application_arn\"",
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

  assert {
    condition = (
      output.expected_input_variable_count == 9
      && output.expected_output_value_count == 9
      && output.expected_interface_literal_count == 26
    )
    error_message = "Interface contract counts must remain pinned for MicroVM helper inputs, outputs, and source literals."
  }
}
