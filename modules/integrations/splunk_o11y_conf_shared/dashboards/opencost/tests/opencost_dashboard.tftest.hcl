mock_provider "signalfx" {}

variables {
  tenant_names    = ["acgw", "bcgw"]
  dashboard_group = "forge-dashboards"
}

run "opencost_dashboard_contract" {
  command = plan

  assert {
    condition = (
      signalfx_dashboard.opencost.name == "OpenCost Tenant Cost"
      && signalfx_dashboard.opencost.dashboard_group == "forge-dashboards"
      && length(signalfx_dashboard.opencost.chart) == 6
    )
    error_message = "OpenCost dashboard must keep its name, group input, and chart count."
  }

  assert {
    condition = alltrue([
      contains([for chart in signalfx_dashboard.opencost.chart : chart.chart_id], signalfx_list_chart.tenant_hourly_compute_cost.id),
      contains([for chart in signalfx_dashboard.opencost.chart : chart.chart_id], signalfx_time_chart.tenant_memory_cost.id),
    ])
    error_message = "OpenCost dashboard must keep its first and final chart wiring."
  }
}
