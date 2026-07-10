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
    )
    error_message = "EC2 runner charts must keep active host, CPU utilization, and top-instance behavior."
  }
}

run "runner_ec2_dashboard_wiring_contract" {
  command = plan

  assert {
    condition = (
      signalfx_dashboard.runner_ec2.name == "EC2 Runners"
      && signalfx_dashboard.runner_ec2.dashboard_group == "forge-dashboard-group"
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
