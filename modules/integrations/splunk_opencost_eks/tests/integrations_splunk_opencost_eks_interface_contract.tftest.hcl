run "integrations_splunk_opencost_eks_interface_contract" {
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
    ]
    expected_output_values = [
      "metrics_endpoint",
      "metrics_host",
      "metrics_path",
      "metrics_port",
      "namespace",
      "prometheus_endpoint",
      "release_name",
      "service_account_name",
      "service_name",
    ]
    expected_interface_literals = [
      "variable \"aws_profile\"",
      "type        = string",
      "description = \"AWS profile to use.\"",
      "default     = null",
      "variable \"aws_region\"",
      "description = \"Default AWS region.\"",
      "variable \"cluster_name\"",
      "description = \"The EKS cluster name and OpenCost default cluster ID.\"",
      "variable \"default_tags\"",
      "type        = map(string)",
      "description = \"A map of tags to apply to resources.\"",
      "default     = {}",
      "output \"metrics_endpoint\"",
      "value = \"http://opencost.opencost.svc.cluster.local:9003/metrics\"",
      "output \"metrics_host\"",
      "value = \"opencost.opencost.svc.cluster.local\"",
      "output \"metrics_path\"",
      "value = \"/metrics\"",
      "output \"metrics_port\"",
      "value = 9003",
      "output \"namespace\"",
      "value = \"opencost\"",
      "output \"prometheus_endpoint\"",
      "value = \"http://prometheus-server.prometheus-system.svc.cluster.local:80\"",
      "output \"release_name\"",
      "output \"service_account_name\"",
      "output \"service_name\"",
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
      output.expected_input_variable_count == 4
      && output.expected_output_value_count == 9
      && output.expected_interface_literal_count == 27
    )
    error_message = "Interface contract counts must remain pinned for inputs, outputs, and source literals."
  }
}
