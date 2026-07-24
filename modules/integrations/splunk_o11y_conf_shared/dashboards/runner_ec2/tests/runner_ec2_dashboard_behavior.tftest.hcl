mock_provider "signalfx" {}

variables {
  tenant_names    = ["tenant-b", "tenant-a"]
  dashboard_group = "forge-dashboard-group"
  dynamic_variables = [
    {
      property               = "aws_region"
      alias                  = "AWS Region"
      description            = "Limit by AWS region"
      values                 = ["us-east-1"]
      value_required         = true
      values_suggested       = ["us-east-1", "us-west-2"]
      restricted_suggestions = true
    }
  ]
}

run "runner_ec2_dashboard_contract" {
  command = plan

  assert {
    condition = (
      signalfx_single_value_chart.chart_active_hosts.name == "# Active hosts"
      && strcontains(signalfx_single_value_chart.chart_active_hosts.program_text, "^aws.ec2.cpu.utilization")
      && signalfx_time_chart.chart_cpu_utilization.name == "CPU utilization (%)"
      && signalfx_time_chart.chart_cpu_utilization.time_range == 3600
      && signalfx_list_chart.chart_top_instances_by_cpu_utilization.sort_by == "-value"
      && signalfx_list_chart.chart_top_instances_by_cpu_utilization.time_range == 3600
      && signalfx_list_chart.chart_disk_summary_utilization.description == "Percent of disk space utilized on all volumes on active hosts with agent installed. Tenant | Instance id | Host"
      && strcontains(signalfx_list_chart.chart_disk_summary_utilization.program_text, ".sum(by=['aws_tag_TenantName', 'host.name', 'host.id', 'AWSUniqueId'])")
      && contains([for field in signalfx_list_chart.chart_disk_summary_utilization.legend_options_fields : field.property if field.enabled], "aws_tag_TenantName")
      && one([for option in signalfx_list_chart.chart_disk_summary_utilization.viz_options : option.display_name if option.label == "C"]) == "Disk utilization"
      && signalfx_time_chart.chart_status_check_failures.time_range == 3600
      && signalfx_list_chart.chart_total_network_errors.name == "Network errors/sec"
      && strcontains(signalfx_list_chart.chart_total_network_errors.program_text, "rollup='rate'")
      && !strcontains(signalfx_list_chart.chart_total_network_errors.program_text, ".count(")
      && strcontains(signalfx_list_chart.chart_top_memory_page_swaps_sec.program_text, "data('vmpage_io.swap.in', filter=filter('cloud.platform', 'aws_ec2', 'aws_eks'), rollup='rate')")
    )
    error_message = "EC2 runner charts must keep one-hour visibility, tenant-aware disk identity, active host, CPU utilization, top-instance, and rate-based network and swap behavior."
  }
}

run "runner_ec2_dashboard_wiring_contract" {
  command = plan

  assert {
    condition = (
      signalfx_dashboard.runner_ec2.name == "EC2 Runners"
      && signalfx_dashboard.runner_ec2.dashboard_group == "forge-dashboard-group"
      && signalfx_dashboard.runner_ec2.variable[0].values == toset(["tenant-a", "tenant-b"])
      && signalfx_dashboard.runner_ec2.variable[0].value_required
      && length(signalfx_dashboard.runner_ec2.chart) == 23
    )
    error_message = "EC2 runner dashboard must keep its name, group input, and chart count."
  }

  assert {
    condition = alltrue([
      contains([for chart in signalfx_dashboard.runner_ec2.chart : chart.chart_id], signalfx_single_value_chart.chart_active_hosts.id),
      contains([for chart in signalfx_dashboard.runner_ec2.chart : chart.chart_id], signalfx_time_chart.chart_status_check_failures.id),
    ])
    error_message = "EC2 runner dashboard must keep its first and final chart wiring."
  }
}
