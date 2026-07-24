mock_provider "signalfx" {}

variables {
  tenant_names    = ["tenant-b", "tenant-a"]
  dashboard_group = "forge-dashboard-group"
  dynamic_variables = [
    {
      property               = "k8s.cluster.name"
      alias                  = "K8S Cluster"
      description            = "Limit by cluster"
      values                 = ["forge-euw1-dev"]
      value_required         = true
      values_suggested       = ["forge-euw1-dev", "forge-use1-prod"]
      restricted_suggestions = true
    }
  ]
}

run "runner_k8s_dashboard_contract" {
  command = plan

  assert {
    condition = (
      signalfx_single_value_chart.k8s_active_pods.name == "# Active pods"
      && strcontains(signalfx_single_value_chart.k8s_active_pods.program_text, "k8s.pod.phase")
      && signalfx_list_chart.k8s_top_10_cpu_usage_per_pod.sort_by == "-value"
      && signalfx_time_chart.k8s_memory_usage_pct.name == "Memory usage (%)"
      && strcontains(signalfx_time_chart.k8s_otel_collector_pods.program_text, "splunk-otel-collector")
      && strcontains(signalfx_time_chart.k8s_node_pressure.program_text, "k8s.node.condition")
      && strcontains(signalfx_time_chart.k8s_otel_exporter_queue_utilization.program_text, "otelcol_exporter_queue_capacity")
      && strcontains(signalfx_time_chart.k8s_otel_telemetry_loss.program_text, "otelcol_receiver_refused_metric_points")
      && strcontains(signalfx_time_chart.k8s_pod_status_reasons.program_text, "filter('k8s.namespace.name', 'tenant-a') or filter('k8s.namespace.name', 'tenant-b')")
    )
    error_message = "K8S runner charts must keep active pod, top CPU, memory percentage, and OTel collector health behavior."
  }
}

run "runner_k8s_dashboard_wiring_contract" {
  command = plan

  assert {
    condition = (
      signalfx_dashboard.runner_k8s.name == "K8S Runners"
      && signalfx_dashboard.runner_k8s.dashboard_group == "forge-dashboard-group"
      && signalfx_dashboard.runner_k8s.variable[0].values == toset(["tenant-a", "tenant-b"])
      && signalfx_dashboard.runner_k8s.variable[0].value_required
      && length(signalfx_dashboard.runner_k8s.chart) == 17
    )
    error_message = "K8S runner dashboard must keep its name, group input, and chart count."
  }

  assert {
    condition = alltrue([
      contains([for chart in signalfx_dashboard.runner_k8s.chart : chart.chart_id], signalfx_single_value_chart.k8s_active_pods.id),
      contains([for chart in signalfx_dashboard.runner_k8s.chart : chart.chart_id], signalfx_time_chart.k8s_otel_collector_pods.id),
      contains([for chart in signalfx_dashboard.runner_k8s.chart : chart.chart_id], signalfx_time_chart.k8s_otel_exporter_queue_utilization.id),
      contains([for chart in signalfx_dashboard.runner_k8s.chart : chart.chart_id], signalfx_time_chart.k8s_pod_status_reasons.id),
    ])
    error_message = "K8S runner dashboard must keep its first and final chart wiring."
  }
}
