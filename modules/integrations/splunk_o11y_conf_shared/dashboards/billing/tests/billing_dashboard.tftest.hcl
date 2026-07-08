mock_provider "signalfx" {}

variables {
  tenant_names    = ["acgw", "bcgw"]
  dashboard_group = "forge-dashboards"
}

run "billing_dashboard_contract" {
  command = plan

  assert {
    condition = (
      signalfx_dashboard.billing.name == "Billing"
      && signalfx_dashboard.billing.dashboard_group == "forge-dashboards"
      && length(signalfx_dashboard.billing.chart) == 8
    )
    error_message = "Billing dashboard must keep its name, group input, and chart count."
  }

  assert {
    condition = alltrue([
      contains([for chart in signalfx_dashboard.billing.chart : chart.chart_id], signalfx_time_chart.cost_per_service.id),
      contains([for chart in signalfx_dashboard.billing.chart : chart.chart_id], signalfx_list_chart.top_tenant_service_net_cost.id),
    ])
    error_message = "Billing dashboard must keep its first and final chart wiring."
  }
}
