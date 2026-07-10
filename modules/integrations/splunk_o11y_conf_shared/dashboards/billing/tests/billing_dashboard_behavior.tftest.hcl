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
    )
    error_message = "Billing dashboard charts must keep total cost and top tenant/service cost SignalFlow behavior."
  }
}

run "billing_dashboard_wiring_contract" {
  command = plan

  assert {
    condition = (
      signalfx_dashboard.billing.name == "Billing"
      && signalfx_dashboard.billing.dashboard_group == "forge-dashboard-group"
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
