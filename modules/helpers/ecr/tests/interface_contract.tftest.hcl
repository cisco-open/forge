run "helpers_ecr_interface_contract" {
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
      "repositories",
      "tags",
    ]
    expected_output_values = [
      "ops_container_repository_names",
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
      "variable \"repositories\"",
      "type = list(object({",
      "repo         = string",
      "mutability   = string",
      "scan_on_push = bool",
      "}))",
      "description = \"A list of ECR repositories to create. Mutability must be 'MUTABLE' or 'IMMUTABLE'.\"",
      "validation {",
      "condition = alltrue([",
      "for r in var.repositories : contains([\"MUTABLE\", \"IMMUTABLE\"], r.mutability)",
      "error_message = \"Each repository 'mutability' must be either 'MUTABLE' or 'IMMUTABLE'.\"",
      "variable \"tags\"",
      "output \"ops_container_repository_names\"",
      "value = [for registry in aws_ecr_repository.ops_container_repository : registry.name]",
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
      && output.expected_output_value_count == 1
      && output.expected_interface_literal_count == 22
    )
    error_message = "Interface contract counts must remain pinned for inputs, outputs, and source literals."
  }
}
