run "integrations_splunk_o11y_conf_shared_dashboards_dynamodb_source_inventory" {
  command = plan

  module {
    source = "../../../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "resource \"signalfx_time_chart\" \"write_throttle_events\"",
      "resource \"signalfx_time_chart\" \"system_errors_ts\"",
      "resource \"signalfx_time_chart\" \"read_capacity_percentage\"",
      "resource \"signalfx_time_chart\" \"returned_item_count\"",
      "resource \"signalfx_single_value_chart\" \"avg_request_latency_single\"",
      "resource \"signalfx_time_chart\" \"avg_request_latency_ts\"",
      "resource \"signalfx_single_value_chart\" \"throttled_requests_single\"",
      "resource \"signalfx_single_value_chart\" \"system_errors_single\"",
      "resource \"signalfx_time_chart\" \"user_errors_ts\"",
      "resource \"signalfx_time_chart\" \"read_throttle_events\"",
      "resource \"signalfx_time_chart\" \"throttled_requests_ts\"",
      "resource \"signalfx_time_chart\" \"write_capacity_percentage\"",
      "resource \"signalfx_single_value_chart\" \"user_errors_single\"",
      "resource \"signalfx_dashboard\" \"dynamodb\"",
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
