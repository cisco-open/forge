run "integrations_splunk_o11y_conf_shared_dashboards_runner_usage_source_inventory" {
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
      "terraform_data.dashboard_parent,",
      "configured_k8s_cluster_names = distinct(flatten([",
      "for var_def in var.dynamic_variables : var_def.values_suggested",
      "if var_def.property == \"k8s.cluster.name\"",
      "resource \"signalfx_dashboard\" \"runner_usage\"",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "Source inventory is missing expected Terraform blocks: ${join(", ", output.missing_expected_literals)}"
  }

  assert {
    condition     = output.expected_literal_count == 17
    error_message = "Source inventory must keep 17 module-specific Terraform and lifecycle literals pinned."
  }
}
