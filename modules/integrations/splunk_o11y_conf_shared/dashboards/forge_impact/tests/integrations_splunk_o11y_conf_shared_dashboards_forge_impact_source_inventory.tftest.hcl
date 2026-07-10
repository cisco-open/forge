run "integrations_splunk_o11y_conf_shared_dashboards_forge_impact_source_inventory" {
  command = plan

  module {
    source = "../../../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "resource \"signalfx_list_chart\" \"runner_totals_by_runtime\"",
      "resource \"signalfx_list_chart\" \"runner_minutes_by_runtime\"",
      "resource \"signalfx_time_chart\" \"active_ec2_runners_by_tenant_and_instance_type\"",
      "resource \"signalfx_list_chart\" \"active_ec2_runners_by_tenant\"",
      "resource \"signalfx_list_chart\" \"active_ec2_runners_by_tenant_and_instance_type\"",
      "resource \"signalfx_list_chart\" \"total_ec2_runners_by_tenant\"",
      "resource \"signalfx_list_chart\" \"ec2_runner_hours_by_tenant\"",
      "resource \"signalfx_list_chart\" \"ec2_runner_hours_by_tenant_and_instance_type\"",
      "resource \"signalfx_list_chart\" \"k8s_runners_by_tenant\"",
      "resource \"signalfx_list_chart\" \"total_k8s_runners_by_tenant\"",
      "resource \"signalfx_list_chart\" \"k8s_runner_hours_by_tenant\"",
      "resource \"terraform_data\" \"dashboard_parent\"",
      "resource \"signalfx_dashboard\" \"forge_impact\"",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "Source inventory is missing expected Terraform blocks: ${join(", ", output.missing_expected_literals)}"
  }

  assert {
    condition     = output.expected_literal_count == 13
    error_message = "Source inventory must keep 13 module-specific Terraform blocks pinned."
  }
}
