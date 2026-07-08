mock_provider "signalfx" {}

variables {
  tenant_names    = ["acgw", "bcgw"]
  dashboard_group = "forge-dashboards"
}

run "ebs_dashboard_contract" {
  command = plan

  assert {
    condition = (
      signalfx_dashboard.ebs.name == "EBS"
      && signalfx_dashboard.ebs.dashboard_group == "forge-dashboards"
      && length(signalfx_dashboard.ebs.chart) == 15
    )
    error_message = "EBS dashboard must keep its name, group input, and chart count."
  }

  assert {
    condition = alltrue([
      contains([for chart in signalfx_dashboard.ebs.chart : chart.chart_id], signalfx_single_value_chart.state.id),
      contains([for chart in signalfx_dashboard.ebs.chart : chart.chart_id], signalfx_time_chart.avg_queue_length.id),
    ])
    error_message = "EBS dashboard must keep its first and final chart wiring."
  }
}
