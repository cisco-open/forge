run "integrations_splunk_o11y_conf_shared_dashboards_runner_ec2_source_inventory" {
  command = plan

  module {
    source = "../../../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "resource \"signalfx_time_chart\" \"chart_disk_ops\"",
      "resource \"signalfx_time_chart\" \"chart_total_memory_overview_bytes\"",
      "resource \"signalfx_time_chart\" \"chart_network_out_bytes_vs_24h_change\"",
      "resource \"signalfx_time_chart\" \"chart_network_out_bytes\"",
      "resource \"signalfx_list_chart\" \"chart_top_instances_by_cpu_utilization\"",
      "resource \"signalfx_time_chart\" \"chart_disk_utilization\"",
      "resource \"signalfx_list_chart\" \"chart_disk_metrics_24h_change\"",
      "resource \"signalfx_list_chart\" \"chart_top_images_by_mean_cpu_utilization\"",
      "resource \"signalfx_time_chart\" \"chart_network_in_bytes\"",
      "resource \"signalfx_time_chart\" \"chart_memory_utilization\"",
      "resource \"signalfx_time_chart\" \"chart_disk_io_bytes\"",
      "resource \"signalfx_time_chart\" \"chart_network_in_bytes_vs_24h_change\"",
      "resource \"signalfx_list_chart\" \"chart_total_network_errors\"",
      "resource \"signalfx_list_chart\" \"chart_top_memory_page_swaps_sec\"",
      "resource \"signalfx_list_chart\" \"chart_active_hosts_per_instance_type\"",
      "resource \"signalfx_time_chart\" \"chart_cpu_utilization\"",
      "resource \"signalfx_list_chart\" \"chart_active_hosts_by_availability_zone\"",
      "resource \"signalfx_list_chart\" \"chart_disk_summary_utilization\"",
      "resource \"signalfx_single_value_chart\" \"chart_hosts_with_agent_installed\"",
      "resource \"signalfx_list_chart\" \"chart_top_5_network_out_bytes\"",
      "resource \"signalfx_single_value_chart\" \"chart_active_hosts\"",
      "resource \"signalfx_list_chart\" \"chart_top_5_network_in_bytes\"",
      "resource \"signalfx_time_chart\" \"chart_status_check_failures\"",
      "resource \"signalfx_dashboard\" \"runner_ec2\"",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "Source inventory is missing expected Terraform blocks: ${join(", ", output.missing_expected_literals)}"
  }

  assert {
    condition     = output.expected_literal_count == 24
    error_message = "Source inventory must keep 24 module-specific Terraform blocks pinned."
  }
}
