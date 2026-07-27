run "integrations_splunk_cloud_s3_runner_logs_interface_contract" {
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
      "lambda_event_source_mapping_maximum_concurrency",
      "log_level",
      "logging_retention_in_days",
      "splunk_hec_endpoint",
      "sqs_redrive_max_receive_count",
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
      "variable \"log_level\"",
      "description = \"Log level for application logging (e.g., INFO, DEBUG, WARN, ERROR)\"",
      "default     = \"INFO\"",
      "variable \"logging_retention_in_days\"",
      "description = \"Log retention period in days\"",
      "type        = number",
      "default     = 3",
      "variable \"lambda_event_source_mapping_maximum_concurrency\"",
      "description = \"Maximum concurrent Lambda invocations for the runner-log SQS event source mapping.\"",
      "default     = 40",
      "variable \"splunk_hec_endpoint\"",
      "description = \"Full URL of Splunk HEC endpoint\"",
      "variable \"sqs_redrive_max_receive_count\"",
      "description = \"Number of source-queue receives allowed before a runner-log message moves to the DLQ.\"",
      "default     = 100",
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
      output.expected_input_variable_count == 9
      && output.expected_output_value_count == 0
      && output.expected_interface_literal_count == 24
    )
    error_message = "Interface contract counts must remain pinned for inputs, outputs, and source literals."
  }
}
