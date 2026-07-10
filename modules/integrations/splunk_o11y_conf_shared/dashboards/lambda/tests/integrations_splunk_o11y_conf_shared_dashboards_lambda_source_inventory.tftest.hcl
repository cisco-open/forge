run "integrations_splunk_o11y_conf_shared_dashboards_lambda_source_inventory" {
  command = plan

  module {
    source = "../../../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "resource \"signalfx_time_chart\" \"provisioned_concurrent_executions_by_version\"",
      "resource \"signalfx_time_chart\" \"provisioned_concurrency_invocations_by_version\"",
      "resource \"signalfx_time_chart\" \"provisioned_concurrency_spillover_invocations_by_version\"",
      "resource \"signalfx_single_value_chart\" \"total_spillover_invocations\"",
      "resource \"signalfx_list_chart\" \"percent_invocations_by_version\"",
      "resource \"signalfx_time_chart\" \"errors_by_version\"",
      "resource \"signalfx_single_value_chart\" \"total_throttles\"",
      "resource \"signalfx_list_chart\" \"avg_duration_by_version\"",
      "resource \"signalfx_single_value_chart\" \"avg_invocation_duration\"",
      "resource \"signalfx_time_chart\" \"throttles_by_version\"",
      "resource \"signalfx_time_chart\" \"invocations_by_version\"",
      "resource \"signalfx_time_chart\" \"invocations\"",
      "resource \"signalfx_single_value_chart\" \"total_errors\"",
      "resource \"signalfx_time_chart\" \"provisioned_concurrency_utilization\"",
      "resource \"signalfx_single_value_chart\" \"total_invocations\"",
      "resource \"signalfx_dashboard\" \"lambda\"",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "Source inventory is missing expected Terraform blocks: ${join(", ", output.missing_expected_literals)}"
  }

  assert {
    condition     = output.expected_literal_count == 16
    error_message = "Source inventory must keep 16 module-specific Terraform blocks pinned."
  }
}
