run "integrations_splunk_o11y_conf_shared_dashboards_ebs_source_inventory" {
  command = plan

  module {
    source = "../../../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "resource \"signalfx_time_chart\" \"byte_utilization_pct\"",
      "resource \"signalfx_time_chart\" \"write_latency\"",
      "resource \"signalfx_time_chart\" \"read_ops\"",
      "resource \"signalfx_time_chart\" \"write_throughput\"",
      "resource \"signalfx_time_chart\" \"rw_bytes_breakdown\"",
      "resource \"signalfx_time_chart\" \"read_latency\"",
      "resource \"signalfx_time_chart\" \"read_throughput\"",
      "resource \"signalfx_single_value_chart\" \"state\"",
      "resource \"signalfx_time_chart\" \"total_read_time\"",
      "resource \"signalfx_time_chart\" \"latency_op\"",
      "resource \"signalfx_time_chart\" \"total_write_time\"",
      "resource \"signalfx_time_chart\" \"read_vs_write_ops\"",
      "resource \"signalfx_time_chart\" \"avg_queue_length\"",
      "resource \"signalfx_time_chart\" \"idle_time\"",
      "resource \"signalfx_time_chart\" \"write_ops\"",
      "resource \"signalfx_dashboard\" \"ebs\"",
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
