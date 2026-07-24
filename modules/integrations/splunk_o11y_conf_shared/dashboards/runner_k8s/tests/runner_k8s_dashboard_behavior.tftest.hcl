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
      && strcontains(signalfx_time_chart.k8s_pod_status_reasons.program_text, "filter('k8s.namespace.name', 'tenant-a') or filter('k8s.namespace.name', 'tenant-b')")
    )
    error_message = "K8S runner charts must keep active pod, top CPU, memory percentage, and tenant pod status behavior."
  }

  assert {
    condition = alltrue([
      for program_text in [
        signalfx_single_value_chart.k8s_available_pods_by_deployments.program_text,
        signalfx_list_chart.k8s_top_10_cpu_usage_per_pod.program_text,
        signalfx_time_chart.k8s_network_bytes_per_sec.program_text,
        signalfx_single_value_chart.k8s_desired_pods_by_deployments.program_text,
        signalfx_list_chart.k8s_network_errors_per_sec.program_text,
        signalfx_time_chart.k8s_memory_usage_pct.program_text,
        signalfx_single_value_chart.k8s_active_pods.program_text,
        signalfx_list_chart.k8s_top_10_pods_by_avg_memory_usage.program_text,
        signalfx_list_chart.k8s_pods_by_phase.program_text,
        signalfx_time_chart.k8s_memory_usage_bytes.program_text,
        signalfx_time_chart.k8s_pod_phase_trend.program_text,
        signalfx_time_chart.k8s_container_restarts.program_text,
        signalfx_time_chart.k8s_pod_status_reasons.program_text,
      ] : strcontains(program_text, "filter('k8s.namespace.name', 'tenant-a') or filter('k8s.namespace.name', 'tenant-b')")
    ])
    error_message = "Every K8S runner chart must explicitly restrict telemetry to configured Forge tenant namespaces."
  }
}

run "runner_k8s_dashboard_wiring_contract" {
  command = plan

  assert {
    condition = (
      signalfx_dashboard.runner_k8s.name == "Forge Tenant - K8S Runners"
      && signalfx_dashboard.runner_k8s.dashboard_group == "forge-dashboard-group"
      && signalfx_dashboard.runner_k8s.variable[0].values == toset(["tenant-a", "tenant-b"])
      && signalfx_dashboard.runner_k8s.variable[0].value_required
      && length(signalfx_dashboard.runner_k8s.chart) == 13
    )
    error_message = "K8S runner dashboard must keep its name, group input, and chart count."
  }

  assert {
    condition = alltrue([
      contains([for chart in signalfx_dashboard.runner_k8s.chart : chart.chart_id], signalfx_single_value_chart.k8s_active_pods.id),
      contains([for chart in signalfx_dashboard.runner_k8s.chart : chart.chart_id], signalfx_time_chart.k8s_container_restarts.id),
      contains([for chart in signalfx_dashboard.runner_k8s.chart : chart.chart_id], signalfx_time_chart.k8s_pod_status_reasons.id),
    ])
    error_message = "K8S runner dashboard must keep its first and final chart wiring."
  }
}
