run "integrations_splunk_o11y_conf_shared_dashboards_k8s_control_plane_interface_contract" {
  command = plan

  module {
    source = "../../../../../tests/tofu/module_interface_contract"
  }

  variables {
    module_path = "."
    expected_input_variables = [
      "dashboard_group",
      "detector_ids",
      "dynamic_variables",
      "platform_namespaces",
    ]
    expected_output_values = []
    expected_interface_literals = [
      "variable \"dashboard_group\"",
      "description = \"Dashboard group name for organizing dashboards.\"",
      "type        = string",
      "variable \"dynamic_variables\"",
      "description = \"Dashboard variable definitions; only the Kubernetes cluster variable is used.\"",
      "type = list(object({",
      "property               = string",
      "alias                  = string",
      "description            = string",
      "values                 = list(string)",
      "value_required         = bool",
      "values_suggested       = list(string)",
      "restricted_suggestions = bool",
      "}))",
      "default = []",
      "variable \"platform_namespaces\"",
      "description = \"Namespaces that contain platform pods required for runner scheduling, networking, and telemetry.\"",
      "type        = list(string)",
      "variable \"detector_ids\"",
      "description = \"Kubernetes detector IDs linked to control-plane health charts.\"",
      "otel_collector_health   = string",
      "platform_pods_unhealthy = string",
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
}
