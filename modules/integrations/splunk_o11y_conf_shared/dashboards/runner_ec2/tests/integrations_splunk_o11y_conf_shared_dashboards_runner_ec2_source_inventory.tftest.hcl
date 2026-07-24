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
      "resource \"signalfx_list_chart\" \"chart_top_instances_by_memory_utilization\"",
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
      "resource \"signalfx_list_chart\" \"chart_active_hosts_missing_agent\"",
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
    condition     = output.expected_literal_count == 26
    error_message = "Source inventory must keep 26 module-specific Terraform blocks pinned."
  }
}

run "runner_ec2_rejects_kubernetes_platform_scope" {
  command = plan

  module {
    source = "../../../../../tests/tofu/module_contract"
  }

  variables {
    module_path        = "."
    recursive          = true
    expected_literals  = []
    forbidden_literals = ["filter('cloud.platform', 'aws_ec2', 'aws_eks')"]
  }

  assert {
    condition     = length(output.present_forbidden_literals) == 0
    error_message = "The tenant EC2 dashboard must not mix EKS node and platform telemetry into EC2 runner charts."
  }
}

run "runner_ec2_rejects_invalid_cloudwatch_stat_aliases" {
  command = plan

  module {
    source = "../../../../../tests/tofu/module_contract"
  }

  variables {
    module_path        = "."
    recursive          = true
    expected_literals  = []
    forbidden_literals = ["filter('stat', 'maximum')"]
  }

  assert {
    condition     = length(output.present_forbidden_literals) == 0
    error_message = "CloudWatch maximum statistics are exposed in Splunk as stat=upper, not stat=maximum."
  }
}
