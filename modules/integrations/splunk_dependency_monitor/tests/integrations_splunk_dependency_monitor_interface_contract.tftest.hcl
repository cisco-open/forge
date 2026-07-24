run "integrations_splunk_dependency_monitor_interface_contract" {
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
      "github_api_version",
      "github_timeout_seconds",
      "log_level",
      "logging_retention_in_days",
      "schedule_expression",
      "splunk_dependency_monitor_config",
      "splunk_http_timeout_seconds",
      "tags",
    ]
    expected_output_values = [
      "lambda_function_arn",
      "lambda_log_group_name",
    ]
    expected_interface_literals = [
      "variable \"aws_profile\"",
      "description = \"AWS profile to use.\"",
      "variable \"aws_region\"",
      "description = \"AWS region in which to run the dependency probe.\"",
      "variable \"github_api_version\"",
      "default     = \"2022-11-28\"",
      "variable \"schedule_expression\"",
      "default     = \"cron(*/5 * * * ? *)\"",
      "variable \"splunk_dependency_monitor_config\"",
      "splunk_hec_url     = string",
      "splunk_index       = string",
      "splunk_metrics_url = string",
      "description = \"Splunk Cloud HEC and Splunk Observability metric-ingest configuration.\"",
      "variable \"splunk_http_timeout_seconds\"",
      "default     = 10",
      "output \"lambda_function_arn\"",
      "value       = module.dependency_monitor.lambda_function_arn",
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
      output.expected_input_variable_count == 11
      && output.expected_output_value_count == 2
      && output.expected_interface_literal_count == 17
    )
    error_message = "Interface contract counts must remain pinned."
  }
}
