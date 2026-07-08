mock_provider "signalfx" {}

variables {
  tenant_names    = ["acgw", "bcgw"]
  dashboard_group = "forge-dashboards"
}

run "forge_impact_dashboard_contract" {
  command = plan

  assert {
    condition = (
      signalfx_dashboard.forge_impact.name == "ForgeCICD Impact"
      && signalfx_dashboard.forge_impact.dashboard_group == "forge-dashboards"
      && length(signalfx_dashboard.forge_impact.chart) == 11
    )
    error_message = "Forge impact dashboard must keep its name, group input, and chart count."
  }

  assert {
    condition = alltrue([
      contains([for chart in signalfx_dashboard.forge_impact.chart : chart.chart_id], signalfx_list_chart.active_ec2_runners_by_tenant.id),
      contains([for chart in signalfx_dashboard.forge_impact.chart : chart.chart_id], signalfx_list_chart.ec2_runner_hours_by_tenant_and_instance_type.id),
    ])
    error_message = "Forge impact dashboard must keep its first and final chart wiring."
  }
}
