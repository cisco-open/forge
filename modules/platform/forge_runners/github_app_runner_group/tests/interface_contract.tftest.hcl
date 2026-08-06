run "platform_forge_runners_github_app_runner_group_interface_contract" {
  command = plan

  module {
    source = "../../../../tests/tofu/module_interface_contract"
  }

  variables {
    module_path = "."
    expected_input_variables = [
      "ghes_org",
      "github_api",
      "github_app",
      "log_level",
      "logging_retention_in_days",
      "prefix",
      "repository_selection",
      "runner_group_name",
      "tags",
    ]
    expected_output_values = []
    expected_interface_literals = [
      "variable \"ghes_org\"",
      "description = \"GitHub organization (GHES or GitHub.com).\"",
      "type        = string",
      "variable \"github_api\"",
      "description = \"Base URL for the GitHub API (set to GHES API endpoint if using Enterprise).\"",
      "default     = \"https://api.github.com\"",
      "variable \"github_app\"",
      "description = \"GitHub App configuration\"",
      "type = object({",
      "key_base64_ssm = object({",
      "arn = string",
      "id_ssm = object({",
      "installation_id_ssm = object({",
      "variable \"log_level\"",
      "description = \"Log level for application logging (e.g., INFO, DEBUG, WARN, ERROR)\"",
      "default     = \"INFO\"",
      "variable \"logging_retention_in_days\"",
      "description = \"Retention in days for CloudWatch Log Group for the Lambdas.\"",
      "type        = number",
      "default     = 30",
      "variable \"prefix\"",
      "description = \"Prefix for all resources\"",
      "variable \"repository_selection\"",
      "description = \"Repository selection type: 'all' or 'selected'.\"",
      "validation {",
      "condition     = contains([\"all\", \"selected\"], var.repository_selection)",
      "error_message = \"repository_selection must be 'all' or 'selected'.\"",
      "variable \"runner_group_name\"",
      "description = \"Name of the GitHub Actions runner group to create/update and attach repositories to.\"",
      "variable \"tags\"",
      "description = \"Tags to apply to created resources.\"",
      "type        = map(string)",
      "default     = {}",
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
      output.expected_input_variable_count == 9
      && output.expected_output_value_count == 0
      && output.expected_interface_literal_count == 33
    )
    error_message = "Interface contract counts must remain pinned for inputs, outputs, and source literals."
  }
}
