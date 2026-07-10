run "platform_arc_scale_set_controller_interface_contract" {
  command = plan

  module {
    source = "../../../../tests/tofu/module_interface_contract"
  }

  variables {
    module_path = "."
    expected_input_variables = [
      "chart_name",
      "chart_version",
      "controller_config",
      "github_app",
      "log_level",
      "migrate_arc_cluster",
      "namespace",
      "release_name",
    ]
    expected_output_values = []
    expected_interface_literals = [
      "variable \"chart_name\"",
      "description = \"Chart URL for the Helm chart\"",
      "type        = string",
      "variable \"chart_version\"",
      "description = \"Chart version for the Helm chart\"",
      "variable \"controller_config\"",
      "type = object({",
      "name = string",
      "variable \"github_app\"",
      "description = \"GitHub App configuration\"",
      "key_base64      = string",
      "id              = string",
      "installation_id = string",
      "variable \"log_level\"",
      "description = \"Log level for the ARC controller (one of: debug, info, warn, error). Case-insensitive.\"",
      "default     = \"INFO\"",
      "variable \"migrate_arc_cluster\"",
      "type        = bool",
      "description = \"Flag to indicate if the cluster is being migrated.\"",
      "default     = false",
      "variable \"namespace\"",
      "description = \"Namespace for chart installation\"",
      "variable \"release_name\"",
      "description = \"Name of the Helm release\"",
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
      && output.expected_output_value_count == 0
      && output.expected_interface_literal_count == 24
    )
    error_message = "Interface contract counts must remain pinned for inputs, outputs, and source literals."
  }
}
