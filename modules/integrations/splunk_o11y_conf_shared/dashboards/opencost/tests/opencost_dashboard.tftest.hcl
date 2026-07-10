mock_provider "signalfx" {}

variables {
  tenant_names    = ["tenant-b", "tenant-a"]
  dashboard_group = "forge-dashboard-group"
  dynamic_variables = [
    {
      property               = "k8s.cluster.name"
      alias                  = "Forge Cluster"
      description            = "Limit by cluster"
      values                 = ["forge-euw1-dev"]
      value_required         = true
      values_suggested       = ["forge-euw1-dev", "forge-use1-prod"]
      restricted_suggestions = true
    }
  ]
}

run "opencost_dashboard_contract" {
  command = plan

  assert {
    condition = (
      signalfx_list_chart.tenant_hourly_compute_cost.name == "Tenant hourly compute cost"
      && strcontains(signalfx_list_chart.tenant_hourly_compute_cost.program_text, "filter('namespace', 'tenant-a') or filter('namespace', 'tenant-b')")
      && strcontains(signalfx_list_chart.tenant_hourly_compute_cost.program_text, "node_cpu_hourly_cost")
      && signalfx_time_chart.tenant_cpu_cost.name == "Tenant CPU cost"
      && strcontains(signalfx_time_chart.tenant_memory_cost.program_text, "node_ram_hourly_cost")
    )
    error_message = "OpenCost charts must render tenant filters and CPU/memory cost metrics from inputs."
  }
}

run "opencost_dashboard_wiring_contract" {
  command = plan

  assert {
    condition = (
      signalfx_dashboard.opencost.name == "OpenCost Tenant Cost"
      && signalfx_dashboard.opencost.dashboard_group == "forge-dashboard-group"
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
