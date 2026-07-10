run "integrations_splunk_o11y_conf_shared_dashboards_billing_source_inventory" {
  command = plan

  module {
    source = "../../../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "resource \"signalfx_time_chart\" \"cost_per_service\"",
      "resource \"signalfx_time_chart\" \"net_cost_per_service\"",
      "resource \"signalfx_time_chart\" \"net_cost_per_tenant\"",
      "resource \"signalfx_time_chart\" \"cost_per_tenant\"",
      "resource \"signalfx_time_chart\" \"total_cost\"",
      "resource \"signalfx_time_chart\" \"total_net_cost\"",
      "resource \"signalfx_time_chart\" \"runner_related_net_cost\"",
      "resource \"signalfx_list_chart\" \"top_tenant_service_net_cost\"",
      "resource \"signalfx_dashboard\" \"billing\"",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "Source inventory is missing expected Terraform blocks: ${join(", ", output.missing_expected_literals)}"
  }

  assert {
    condition     = output.expected_literal_count == 9
    error_message = "Source inventory must keep 9 module-specific Terraform blocks pinned."
  }
}
