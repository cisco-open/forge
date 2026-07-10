run "platform_forge_runners_github_global_lock_interface_contract" {
  command = plan

  module {
    source = "../../../../tests/tofu/module_interface_contract"
  }

  variables {
    module_path = "."
    expected_input_variables = [
      "github_app",
      "log_level",
      "logging_retention_in_days",
      "prefix",
      "tags",
    ]
    expected_output_values = [
      "dynamodb_policy_arn",
    ]
    expected_interface_literals = [
      "variable \"github_app\"",
      "description = \"GitHub App configuration\"",
      "type = object({",
      "key_base64_ssm = object({",
      "arn = string",
      "id_ssm = object({",
      "installation_id_ssm = object({",
      "variable \"log_level\"",
      "type        = string",
      "description = \"Log level for application logging (e.g., INFO, DEBUG, WARN, ERROR)\"",
      "default     = \"INFO\"",
      "variable \"logging_retention_in_days\"",
      "description = \"Retention in days for CloudWatch Log Group for the Lambdas.\"",
      "type        = number",
      "default     = 30",
      "variable \"prefix\"",
      "description = \"Prefix for all resources\"",
      "variable \"tags\"",
      "description = \"Tags to apply to created resources.\"",
      "type        = map(string)",
      "default     = {}",
      "output \"dynamodb_policy_arn\"",
      "description = \"ARN of the IAM policy granting DynamoDB lock table CRUD access.\"",
      "value       = aws_iam_policy.dynamodb_policy.arn",
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
      && output.expected_interface_literal_count == 24
    )
    error_message = "Interface contract counts must remain pinned for inputs, outputs, and source literals."
  }
}
