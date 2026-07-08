mock_provider "signalfx" {}

variables {
  tenant_names    = ["acgw", "bcgw"]
  dashboard_group = "forge-dashboards"
}

run "runner_k8s_dashboard_contract" {
  command = plan

  assert {
    condition = (
      signalfx_dashboard.runner_k8s.name == "K8S Runners"
      && signalfx_dashboard.runner_k8s.dashboard_group == "forge-dashboards"
      && length(signalfx_dashboard.runner_k8s.chart) == 13
    )
    error_message = "K8S runner dashboard must keep its name, group input, and chart count."
  }

  assert {
    condition = alltrue([
      contains([for chart in signalfx_dashboard.runner_k8s.chart : chart.chart_id], signalfx_single_value_chart.k8s_active_pods.id),
      contains([for chart in signalfx_dashboard.runner_k8s.chart : chart.chart_id], signalfx_time_chart.k8s_otel_collector_pods.id),
    ])
    error_message = "K8S runner dashboard must keep its first and final chart wiring."
  }
}
