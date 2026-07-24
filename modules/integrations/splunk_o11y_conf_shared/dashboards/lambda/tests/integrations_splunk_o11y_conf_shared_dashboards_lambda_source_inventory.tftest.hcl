run "integrations_splunk_o11y_conf_shared_dashboards_lambda_source_inventory" {
  command = plan

  module {
    source = "../../../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "resource \"signalfx_list_chart\" \"percent_invocations_by_version\"",
      "resource \"signalfx_time_chart\" \"errors_by_version\"",
      "resource \"signalfx_single_value_chart\" \"total_throttles\"",
      "resource \"signalfx_list_chart\" \"avg_duration_by_version\"",
      "resource \"signalfx_single_value_chart\" \"avg_invocation_duration\"",
      "resource \"signalfx_time_chart\" \"throttles_by_version\"",
      "resource \"signalfx_time_chart\" \"invocations_by_version\"",
      "resource \"signalfx_time_chart\" \"invocations\"",
      "resource \"signalfx_single_value_chart\" \"total_errors\"",
      "resource \"signalfx_single_value_chart\" \"total_invocations\"",
      "resource \"signalfx_list_chart\" \"top_tenants_by_errors\"",
      "resource \"signalfx_list_chart\" \"top_tenants_by_throttles\"",
      "resource \"signalfx_list_chart\" \"top_lambdas_by_errors\"",
      "resource \"signalfx_list_chart\" \"top_lambdas_by_throttles\"",
      "resource \"terraform_data\" \"dashboard_parent\"",
      "terraform_data.dashboard_parent,",
      "resource \"signalfx_dashboard\" \"lambda\"",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "Source inventory is missing expected Terraform blocks: ${join(", ", output.missing_expected_literals)}"
  }

  assert {
    condition     = output.expected_literal_count == 17
    error_message = "Source inventory must keep 17 live-backed module-specific Terraform and lifecycle literals pinned."
  }
}

run "lambda_rejects_unavailable_provisioned_concurrency_metrics" {
  command = plan

  module {
    source = "../../../../../tests/tofu/module_contract"
  }

  variables {
    module_path       = "."
    recursive         = true
    expected_literals = []
    forbidden_literals = [
      "ProvisionedConcurrentExecutions",
      "ProvisionedConcurrencyInvocations",
      "ProvisionedConcurrencySpilloverInvocations",
      "ProvisionedConcurrencyUtilization",
    ]
  }

  assert {
    condition     = length(output.present_forbidden_literals) == 0
    error_message = "Unavailable provisioned-concurrency metrics must not create permanently empty Lambda charts."
  }
}
