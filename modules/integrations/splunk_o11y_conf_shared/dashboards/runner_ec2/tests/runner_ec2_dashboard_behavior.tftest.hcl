mock_provider "signalfx" {}

variables {
  tenant_names    = ["tenant-b", "tenant-a"]
  dashboard_group = "forge-dashboard-group"
  detector_ids = {
    cpu    = "forge-runner-cpu-detector"
    disk   = "forge-runner-disk-detector"
    memory = "forge-runner-memory-detector"
  }
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
      && strcontains(signalfx_single_value_chart.chart_active_hosts.program_text, "filter('aws_tag_TenantName', '*')")
      && signalfx_single_value_chart.chart_hosts_with_agent_installed.name == "OTel host coverage (%)"
      && strcontains(signalfx_single_value_chart.chart_hosts_with_agent_installed.program_text, "filter('cloud.platform', 'aws_ec2')")
      && strcontains(signalfx_single_value_chart.chart_hosts_with_agent_installed.program_text, "filter('aws_tag_TenantName', '*')")
      && strcontains(signalfx_single_value_chart.chart_hosts_with_agent_installed.program_text, "(otel / active).scale(100)")
      && !strcontains(signalfx_single_value_chart.chart_hosts_with_agent_installed.program_text, "aws_eks")
      && signalfx_list_chart.chart_active_hosts_missing_agent.name == "Active hosts missing Splunk OTel agent"
      && strcontains(signalfx_list_chart.chart_active_hosts_missing_agent.program_text, "filter=filter('aws_tag_TenantName', '*') and not filter('host.id', '*')")
      && strcontains(signalfx_list_chart.chart_active_hosts_missing_agent.program_text, "'aws_tag_TenantName', 'aws_instance_id', 'aws_image_id', 'aws_tag_Name'")
      && alltrue([
        for property in ["aws_tag_TenantName", "aws_instance_id", "aws_image_id", "aws_tag_Name"] :
        contains([for field in signalfx_list_chart.chart_active_hosts_missing_agent.legend_options_fields : field.property if field.enabled], property)
      ])
      && signalfx_time_chart.chart_cpu_utilization.name == "CPU utilization (%)"
      && signalfx_time_chart.chart_cpu_utilization.time_range == 3600
      && strcontains(signalfx_time_chart.chart_cpu_utilization.program_text, "alerts(detector_id='forge-runner-cpu-detector')")
      && !strcontains(signalfx_time_chart.chart_cpu_utilization.program_text, "autodetect_id=")
      && strcontains(signalfx_time_chart.chart_disk_utilization.program_text, "alerts(detector_id='forge-runner-disk-detector')")
      && !strcontains(signalfx_time_chart.chart_disk_utilization.program_text, "autodetect_id=")
      && strcontains(signalfx_time_chart.chart_memory_utilization.program_text, "alerts(detector_id='forge-runner-memory-detector')")
      && !strcontains(signalfx_time_chart.chart_memory_utilization.program_text, "autodetect_id=")
      && signalfx_list_chart.chart_top_instances_by_cpu_utilization.sort_by == "-value"
      && signalfx_list_chart.chart_top_instances_by_cpu_utilization.time_range == 3600
      && signalfx_list_chart.chart_disk_summary_utilization.description == "Percent of disk space utilized on all volumes on active hosts with agent installed. Tenant | Instance id | Host"
      && strcontains(signalfx_list_chart.chart_disk_summary_utilization.program_text, ".sum(by=['aws_tag_TenantName', 'aws_instance_id', 'host.name', 'host.id', 'AWSUniqueId', 'mountpoint', 'device'])")
      && contains([for field in signalfx_list_chart.chart_disk_summary_utilization.legend_options_fields : field.property if field.enabled], "aws_tag_TenantName")
      && contains([for field in signalfx_list_chart.chart_disk_summary_utilization.legend_options_fields : field.property if field.enabled], "aws_instance_id")
      && contains([for field in signalfx_list_chart.chart_disk_summary_utilization.legend_options_fields : field.property if field.enabled], "mountpoint")
      && contains([for field in signalfx_list_chart.chart_disk_summary_utilization.legend_options_fields : field.property if field.enabled], "device")
      && one([for option in signalfx_list_chart.chart_disk_summary_utilization.viz_options : option.display_name if option.label == "C"]) == "Disk utilization"
      && signalfx_list_chart.chart_top_instances_by_memory_utilization.name == "Top instances by memory utilization (%)"
      && strcontains(signalfx_list_chart.chart_top_instances_by_memory_utilization.program_text, "filter('cloud.platform', 'aws_ec2')")
      && strcontains(signalfx_list_chart.chart_top_instances_by_memory_utilization.program_text, ".sum(by=['aws_tag_TenantName', 'aws_instance_id', 'host.id', 'host.name'])")
      && signalfx_list_chart.chart_top_instances_by_memory_utilization.color_by == "Scale"
      && signalfx_list_chart.chart_top_instances_by_memory_utilization.sort_by == "-value"
      && signalfx_time_chart.chart_status_check_failures.time_range == 3600
      && strcontains(signalfx_time_chart.chart_status_check_failures.program_text, "filter('stat', 'upper')")
      && !strcontains(signalfx_time_chart.chart_status_check_failures.program_text, "filter('stat', 'maximum')")
      && signalfx_list_chart.chart_total_network_errors.name == "Network errors/sec"
      && strcontains(signalfx_list_chart.chart_total_network_errors.program_text, "rollup='rate'")
      && !strcontains(signalfx_list_chart.chart_total_network_errors.program_text, ".count(")
      && strcontains(signalfx_list_chart.chart_top_memory_page_swaps_sec.program_text, "data('vmpage_io.swap.in', filter=filter('cloud.platform', 'aws_ec2'), rollup='rate')")
      && !strcontains(signalfx_time_chart.chart_disk_utilization.program_text, "aws_eks")
      && !strcontains(signalfx_time_chart.chart_memory_utilization.program_text, "aws_eks")
      && strcontains(signalfx_list_chart.job_runs_high_peak_cpu.program_text, "filter('aws_tag_ghr_job_url', '*')")
      && strcontains(signalfx_list_chart.job_runs_high_peak_cpu.program_text, ".above(85, inclusive=True).top(count=20)")
      && length(signalfx_list_chart.job_runs_high_peak_cpu.color_scale) == 3
      && one([for scale in signalfx_list_chart.job_runs_high_peak_cpu.color_scale : scale.lt if scale.color == "blue"]) == 85
      && strcontains(signalfx_list_chart.job_runs_low_peak_cpu.program_text, ".below(20).bottom(count=20)")
      && length(signalfx_list_chart.job_runs_low_peak_cpu.color_scale) == 3
      && one([for scale in signalfx_list_chart.job_runs_low_peak_cpu.color_scale : scale.gte if scale.color == "blue"]) == 20
      && strcontains(signalfx_list_chart.job_runs_high_peak_memory.program_text, "system.memory.usage")
      && strcontains(signalfx_list_chart.job_runs_high_peak_memory.program_text, ".above(85, inclusive=True).top(count=20)")
      && length(signalfx_list_chart.job_runs_high_peak_memory.color_scale) == 3
      && one([for scale in signalfx_list_chart.job_runs_high_peak_memory.color_scale : scale.lt if scale.color == "blue"]) == 85
      && strcontains(signalfx_list_chart.job_runs_low_peak_memory.program_text, ".below(40).bottom(count=20)")
      && length(signalfx_list_chart.job_runs_low_peak_memory.color_scale) == 3
      && one([for scale in signalfx_list_chart.job_runs_low_peak_memory.color_scale : scale.gte if scale.color == "blue"]) == 40
      && strcontains(signalfx_list_chart.runner_classes_by_mean_peak_cpu.program_text, "aws_tag_ghr_runner_labels")
      && strcontains(signalfx_list_chart.runner_classes_by_mean_peak_memory.program_text, "aws_instance_type")
      && strcontains(signalfx_list_chart.job_runs_high_peak_filesystem.program_text, "system.filesystem.usage")
      && strcontains(signalfx_list_chart.job_runs_high_peak_filesystem.program_text, ".above(80, inclusive=True).top(count=20)")
      && length(signalfx_list_chart.job_runs_high_peak_filesystem.color_scale) == 3
      && one([for scale in signalfx_list_chart.job_runs_high_peak_filesystem.color_scale : scale.lt if scale.color == "blue"]) == 80
    )
    error_message = "EC2 runner charts must keep Forge-owned health overlays plus job-aware CPU, memory, filesystem, and runner-class right-sizing behavior."
  }
}

run "runner_ec2_dashboard_wiring_contract" {
  command = plan

  assert {
    condition = (
      signalfx_dashboard.runner_ec2.name == "Forge Tenant - EC2 Runners"
      && signalfx_dashboard.runner_ec2.dashboard_group == "forge-dashboard-group"
      && length(signalfx_dashboard.runner_ec2.variable[0].values) == 0
      && !signalfx_dashboard.runner_ec2.variable[0].value_required
      && signalfx_dashboard.runner_ec2.variable[0].values_suggested == toset(["tenant-a", "tenant-b"])
      && signalfx_dashboard.runner_ec2.variable[0].restricted_suggestions
      && length(signalfx_dashboard.runner_ec2.chart) == 32
    )
    error_message = "EC2 runner dashboard must keep its name, group input, and chart count."
  }

  assert {
    condition = alltrue([
      contains([for chart in signalfx_dashboard.runner_ec2.chart : chart.chart_id], signalfx_single_value_chart.chart_active_hosts.id),
      contains([for chart in signalfx_dashboard.runner_ec2.chart : chart.chart_id], signalfx_list_chart.chart_active_hosts_missing_agent.id),
      contains([for chart in signalfx_dashboard.runner_ec2.chart : chart.chart_id], signalfx_list_chart.chart_top_instances_by_memory_utilization.id),
      contains([for chart in signalfx_dashboard.runner_ec2.chart : chart.chart_id], signalfx_time_chart.chart_status_check_failures.id),
      contains([for chart in signalfx_dashboard.runner_ec2.chart : chart.chart_id], signalfx_list_chart.job_runs_high_peak_cpu.id),
      contains([for chart in signalfx_dashboard.runner_ec2.chart : chart.chart_id], signalfx_list_chart.job_runs_low_peak_memory.id),
      contains([for chart in signalfx_dashboard.runner_ec2.chart : chart.chart_id], signalfx_list_chart.runner_classes_by_mean_peak_cpu.id),
      contains([for chart in signalfx_dashboard.runner_ec2.chart : chart.chart_id], signalfx_list_chart.job_runs_high_peak_filesystem.id),
    ])
    error_message = "EC2 runner dashboard must keep its first and final chart wiring."
  }
}
