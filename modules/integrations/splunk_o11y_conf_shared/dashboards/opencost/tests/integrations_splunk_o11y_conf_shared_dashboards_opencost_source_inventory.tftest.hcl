run "integrations_splunk_o11y_conf_shared_dashboards_opencost_source_inventory" {
  command = plan

  module {
    source = "../../../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "resource \"signalfx_list_chart\" \"tenant_hourly_compute_cost\"",
      "resource \"signalfx_list_chart\" \"tenant_monthly_compute_run_rate\"",
      "resource \"signalfx_time_chart\" \"tenant_compute_cost_trend\"",
      "resource \"signalfx_time_chart\" \"tenant_cpu_cost\"",
      "resource \"signalfx_time_chart\" \"tenant_memory_cost\"",
      "resource \"signalfx_list_chart\" \"top_pod_compute_cost\"",
      "resource \"signalfx_dashboard\" \"opencost\"",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "Source inventory is missing expected Terraform blocks: ${join(", ", output.missing_expected_literals)}"
  }

  assert {
    condition     = output.expected_literal_count == 7
    error_message = "Source inventory must keep 7 module-specific Terraform blocks pinned."
  }
}
