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
      "resource \"terraform_data\" \"runner_usage_dashboard_parent\"",
      "terraform_data.runner_usage_dashboard_parent,",
      "resource \"signalfx_dashboard\" \"forge_impact\"",
      "resource \"signalfx_dashboard\" \"runner_usage\"",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "Source inventory is missing expected Terraform blocks: ${join(", ", output.missing_expected_literals)}"
  }

  assert {
    condition     = output.expected_literal_count == 29
    error_message = "Source inventory must keep 29 module-specific Terraform and lifecycle literals pinned."
  }
}

run "forge_impact_rejects_unattributed_dynamodb_tenant_rankings" {
  command = plan

  module {
    source = "../../../../../tests/tofu/module_contract"
  }

  variables {
    module_path       = "."
    recursive         = true
    expected_literals = []
    forbidden_literals = [
      "top_tenants_dynamodb_throttles",
      "top_tenants_dynamodb_system_errors",
    ]
  }

  assert {
    condition     = length(output.present_forbidden_literals) == 0
    error_message = "DynamoDB failure metrics must not be ranked by tenant until live metrics expose a confirmed tenant identity."
  }
}
