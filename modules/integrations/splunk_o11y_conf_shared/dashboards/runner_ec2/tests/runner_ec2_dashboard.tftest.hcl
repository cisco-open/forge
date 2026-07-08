mock_provider "signalfx" {}

variables {
  tenant_names    = ["acgw", "bcgw"]
  dashboard_group = "forge-dashboards"
}

run "runner_ec2_dashboard_contract" {
  command = plan

  assert {
    condition = (
      signalfx_dashboard.runner_ec2.name == "EC2 Runners"
      && signalfx_dashboard.runner_ec2.dashboard_group == "forge-dashboards"
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
