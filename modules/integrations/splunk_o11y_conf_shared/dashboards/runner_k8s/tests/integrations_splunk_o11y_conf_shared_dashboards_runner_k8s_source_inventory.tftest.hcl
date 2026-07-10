run "integrations_splunk_o11y_conf_shared_dashboards_runner_k8s_source_inventory" {
  command = plan

  module {
    source = "../../../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "resource \"signalfx_single_value_chart\" \"k8s_available_pods_by_deployments\"",
      "resource \"signalfx_list_chart\" \"k8s_top_10_cpu_usage_per_pod\"",
      "resource \"signalfx_time_chart\" \"k8s_network_bytes_per_sec\"",
      "resource \"signalfx_single_value_chart\" \"k8s_desired_pods_by_deployments\"",
      "resource \"signalfx_list_chart\" \"k8s_network_errors_per_sec\"",
      "resource \"signalfx_time_chart\" \"k8s_memory_usage_pct\"",
      "resource \"signalfx_single_value_chart\" \"k8s_active_pods\"",
      "resource \"signalfx_list_chart\" \"k8s_top_10_pods_by_avg_memory_usage\"",
      "resource \"signalfx_list_chart\" \"k8s_pods_by_phase\"",
      "resource \"signalfx_time_chart\" \"k8s_memory_usage_bytes\"",
      "resource \"signalfx_time_chart\" \"k8s_pod_phase_trend\"",
      "resource \"signalfx_time_chart\" \"k8s_container_restarts\"",
      "resource \"signalfx_time_chart\" \"k8s_otel_collector_pods\"",
      "resource \"signalfx_dashboard\" \"runner_k8s\"",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "Source inventory is missing expected Terraform blocks: ${join(", ", output.missing_expected_literals)}"
  }

  assert {
    condition     = output.expected_literal_count == 14
    error_message = "Source inventory must keep 14 module-specific Terraform blocks pinned."
  }
}
