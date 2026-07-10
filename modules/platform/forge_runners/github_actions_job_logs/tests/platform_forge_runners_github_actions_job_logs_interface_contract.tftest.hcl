run "platform_forge_runners_github_actions_job_logs_interface_contract" {
  command = plan

  module {
    source = "../../../../tests/tofu/module_interface_contract"
  }

  variables {
    module_path = "."
    expected_input_variables = [
      "event_bus_name",
      "ghes_url",
      "github_app",
      "log_level",
      "logging_retention_in_days",
      "prefix",
      "shared_role_arns",
      "tags",
    ]
    expected_output_values = [
      "internal_s3_reader_role_arn",
      "s3_bucket_arn",
    ]
    expected_interface_literals = [
      "variable \"event_bus_name\"",
      "type        = string",
      "description = \"Name of the EventBridge event bus to listen for workflow job events.\"",
      "variable \"ghes_url\"",
      "description = \"GitHub Enterprise Server URL.\"",
      "default     = \"\"",
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
      "variable \"shared_role_arns\"",
      "description = \"Optional list of consumer identifier to IAM Role ARN granted read/list on tenant's github job logs.\"",
      "type        = list(string)",
      "default     = []",
      "variable \"tags\"",
      "description = \"Tags to apply to created resources.\"",
      "type        = map(string)",
      "default     = {}",
      "output \"internal_s3_reader_role_arn\"",
      "description = \"The ARN of the IAM role used for reading from the S3 bucket.\"",
      "value       = aws_iam_role.internal_s3_reader.arn",
      "output \"s3_bucket_arn\"",
      "description = \"The ARN of the S3 bucket where GitHub Actions job logs are stored.\"",
      "value       = aws_s3_bucket.gh_logs.arn",
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
      && output.expected_output_value_count == 2
      && output.expected_interface_literal_count == 36
    )
    error_message = "Interface contract counts must remain pinned for inputs, outputs, and source literals."
  }
}
