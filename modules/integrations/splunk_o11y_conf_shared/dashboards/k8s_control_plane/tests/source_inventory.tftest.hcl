run "integrations_splunk_o11y_conf_shared_dashboards_k8s_control_plane_source_inventory" {
  command = plan

  module {
    source = "../../../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "resource \"signalfx_time_chart\" \"platform_pod_health\"",
      "resource \"signalfx_time_chart\" \"otel_collector_pods\"",
      "resource \"signalfx_time_chart\" \"node_pressure\"",
      "resource \"signalfx_time_chart\" \"otel_exporter_queue_utilization\"",
      "resource \"signalfx_time_chart\" \"otel_telemetry_loss\"",
      "resource \"terraform_data\" \"dashboard_parent\"",
      "terraform_data.dashboard_parent,",
      "resource \"signalfx_dashboard\" \"k8s_control_plane\"",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "Source inventory is missing expected Terraform blocks: ${join(", ", output.missing_expected_literals)}"
  }

  assert {
    condition     = output.expected_literal_count == 8
    error_message = "Source inventory must keep eight module-specific Terraform and lifecycle literals pinned."
  }
}
