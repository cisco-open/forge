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

run "billing_dashboard_contract" {
  command = plan

  assert {
    condition = (
      signalfx_time_chart.total_cost.name == "Total Cost"
      && signalfx_time_chart.total_cost.time_range == 3600
      && strcontains(signalfx_time_chart.total_cost.program_text, "forge.per_service.cost_usd")
      && signalfx_list_chart.top_tenant_service_net_cost.sort_by == "-value"
      && strcontains(signalfx_list_chart.top_tenant_service_net_cost.program_text, ".top(count=20)")
      && signalfx_time_chart.non_tenant_cost_per_module.name == "Non-tenant cost per module"
      && strcontains(signalfx_time_chart.non_tenant_cost_per_module.program_text, "filter('forgecicd_scope', 'module')")
      && strcontains(signalfx_time_chart.non_tenant_cost_per_module.program_text, "'forgecicd_module_group', 'forgecicd_module'")
      && strcontains(signalfx_time_chart.non_tenant_net_cost_per_service.program_text, "B.sum(by=['service', 'usage_month', 'usage_year'])")
      && signalfx_list_chart.top_non_tenant_module_service_net_cost.sort_by == "-value"
      && strcontains(signalfx_list_chart.top_non_tenant_module_service_net_cost.program_text, ".top(count=20)")
    )
    error_message = "Billing dashboard charts must keep tenant and non-tenant module cost SignalFlow behavior."
  }
}

run "billing_dashboard_wiring_contract" {
  command = plan

  assert {
    condition = (
      signalfx_dashboard.billing.name == "Forge Billing and Cost - AWS"
      && signalfx_dashboard.billing.dashboard_group == "forge-dashboard-group"
      && signalfx_dashboard.billing.time_range == "-31d"
      && length(signalfx_dashboard.billing.chart) == 12
    )
    error_message = "Billing dashboard must keep its name, group input, 31-day default time range, and chart count."
  }

  assert {
    condition = alltrue([
      contains([for chart in signalfx_dashboard.billing.chart : chart.chart_id], signalfx_time_chart.cost_per_service.id),
      contains([for chart in signalfx_dashboard.billing.chart : chart.chart_id], signalfx_list_chart.top_tenant_service_net_cost.id),
      contains([for chart in signalfx_dashboard.billing.chart : chart.chart_id], signalfx_time_chart.non_tenant_cost_per_module.id),
      contains([for chart in signalfx_dashboard.billing.chart : chart.chart_id], signalfx_list_chart.top_non_tenant_module_service_net_cost.id),
    ])
    error_message = "Billing dashboard must keep tenant and non-tenant module chart wiring."
  }
}
