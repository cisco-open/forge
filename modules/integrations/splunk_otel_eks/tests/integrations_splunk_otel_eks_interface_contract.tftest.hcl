run "integrations_splunk_otel_eks_interface_contract" {
  command = plan

  module {
    source = "../../../tests/tofu/module_interface_contract"
  }

  variables {
    module_path = "."
    expected_input_variables = [
      "aws_profile",
      "aws_region",
      "cluster_name",
      "default_tags",
      "prometheus_autodiscovery_enabled",
      "splunk_otel_collector",
      "tags",
    ]
    expected_output_values = []
    expected_interface_literals = [
      "variable \"aws_profile\"",
      "type        = string",
      "description = \"AWS profile to use.\"",
      "variable \"aws_region\"",
      "description = \"Default AWS region.\"",
      "variable \"cluster_name\"",
      "description = \"The name of the EKS cluster\"",
      "variable \"default_tags\"",
      "type        = map(string)",
      "description = \"A map of tags to apply to resources.\"",
      "variable \"prometheus_autodiscovery_enabled\"",
      "type        = bool",
      "description = \"Enable Splunk OTel annotation-based Prometheus autodiscovery for pods and services such as OpenCost.\"",
      "default     = false",
      "variable \"splunk_otel_collector\"",
      "description = \"Configuration for the Splunk OpenTelemetry Collector\"",
      "type = object({",
      "splunk_platform_endpoint        = string",
      "splunk_platform_index           = string",
      "gateway                         = bool",
      "environment                     = string",
      "discovery                       = bool",
      "splunk_observability_realm      = string",
      "splunk_observability_ingest_url = string",
      "splunk_observability_api_url    = string",
      "splunk_observability_profiling  = bool",
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
      output.expected_input_variable_count == 7
      && output.expected_output_value_count == 0
      && output.expected_interface_literal_count == 27
    )
    error_message = "Interface contract counts must remain pinned for inputs, outputs, and source literals."
  }
}
