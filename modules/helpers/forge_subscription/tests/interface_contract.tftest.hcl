run "helpers_forge_subscription_interface_contract" {
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
      "forge",
      "tags",
    ]
    expected_output_values = []
    expected_interface_literals = [
      "variable \"aws_profile\"",
      "type        = string",
      "description = \"AWS profile to use.\"",
      "variable \"aws_region\"",
      "description = \"Default AWS region.\"",
      "variable \"default_tags\"",
      "type        = map(string)",
      "description = \"A map of tags to apply to resources.\"",
      "variable \"forge\"",
      "type = object({",
      "runner_roles = list(string)",
      "ecr_repositories = object({",
      "names                  = list(string)",
      "ecr_access_account_ids = list(string)",
      "regions                = list(string)",
      "description = \"Configuration for Forge runners.\"",
      "default = {",
      "runner_roles = []",
      "ecr_repositories = {",
      "names                  = []",
      "ecr_access_account_ids = []",
      "regions                = []",
      "variable \"tags\"",
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
      output.expected_input_variable_count == 5
      && output.expected_output_value_count == 0
      && output.expected_interface_literal_count == 23
    )
    error_message = "Interface contract counts must remain pinned for inputs, outputs, and source literals."
  }
}
