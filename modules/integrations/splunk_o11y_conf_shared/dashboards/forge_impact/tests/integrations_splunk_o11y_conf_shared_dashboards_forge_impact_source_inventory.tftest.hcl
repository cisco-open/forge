run "integrations_splunk_o11y_conf_shared_dashboards_forge_impact_source_inventory" {
  command = plan

  module {
    source = "../../../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "resource \"signalfx_list_chart\" \"top_tenants_lambda_errors\"",
      "resource \"signalfx_list_chart\" \"top_tenants_lambda_throttles\"",
      "resource \"signalfx_list_chart\" \"top_tenants_ec2_memory\"",
      "resource \"signalfx_list_chart\" \"top_tenants_ec2_cpu\"",
      "resource \"signalfx_list_chart\" \"top_tenants_k8s_pending_pods\"",
      "resource \"signalfx_list_chart\" \"top_tenants_k8s_failed_pods\"",
      "resource \"signalfx_list_chart\" \"top_tenants_sqs_backlog\"",
      "resource \"signalfx_list_chart\" \"top_tenants_sqs_dlq_backlog\"",
      "resource \"signalfx_list_chart\" \"top_tenants_ec2_disk\"",
      "resource \"signalfx_list_chart\" \"top_tenants_ec2_status_failures\"",
      "resource \"signalfx_list_chart\" \"top_tenants_k8s_restarts\"",
      "resource \"signalfx_list_chart\" \"top_tenants_ebs_queue_length\"",
      "resource \"signalfx_list_chart\" \"top_tenants_ebs_iops_exceeded\"",
      "resource \"terraform_data\" \"dashboard_parent\"",
      "terraform_data.dashboard_parent,",
      "configured_k8s_cluster_names = distinct(flatten([",
      "for var_def in var.dynamic_variables : var_def.values_suggested",
      "if var_def.property == \"k8s.cluster.name\"",
      "resource \"signalfx_dashboard\" \"forge_impact\"",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "Source inventory is missing expected Terraform blocks: ${join(", ", output.missing_expected_literals)}"
  }

  assert {
    condition     = output.expected_literal_count == 19
    error_message = "Source inventory must keep 19 module-specific Terraform and lifecycle literals pinned."
  }
}
