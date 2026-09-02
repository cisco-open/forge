mock_provider "signalfx" {}

variables {
  tenant_names    = ["tenant-b", "tenant-a"]
  dashboard_group = "forge-dashboard-group"
  detector_ids = {
    otel_no_data        = "k8s-no-data-detector-id"
    tenant_pods_pending = "tenant-pending-detector-id"
  }
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
      && signalfx_single_value_chart.k8s_active_pods.description == "Includes runner, listener, and controller pods."
      && signalfx_list_chart.k8s_pods_by_phase.description == "Runner, listener, and controller pod counts by phase."
      && signalfx_single_value_chart.k8s_available_pods_by_deployments.name == "# Available ARC controllers"
      && signalfx_single_value_chart.k8s_desired_pods_by_deployments.name == "# Desired ARC controllers"
      && strcontains(signalfx_single_value_chart.k8s_available_pods_by_deployments.program_text, "filter('k8s.deployment.name', '*-gha-rs-controller')")
      && strcontains(signalfx_single_value_chart.k8s_desired_pods_by_deployments.program_text, "filter('k8s.deployment.name', '*-gha-rs-controller')")
      && strcontains(signalfx_single_value_chart.k8s_active_pods.program_text, "k8s.pod.phase")
      && signalfx_list_chart.k8s_top_10_cpu_usage_per_pod.sort_by == "-value"
      && signalfx_time_chart.k8s_memory_usage_pct.name == "Memory usage (%)"
      && strcontains(signalfx_time_chart.k8s_pod_status_reasons.program_text, "filter('k8s.namespace.name', 'tenant-a') or filter('k8s.namespace.name', 'tenant-b')")
      && alltrue([
        for property in ["k8s.cluster.name", "k8s.namespace.name", "k8s.pod.name", "k8s.pod.uid", "k8s.node.name"] :
        contains([for field in signalfx_time_chart.k8s_memory_usage_bytes.legend_options_fields : field.property if field.enabled], property)
      ])
      && alltrue([
        for property in ["kubernetes_cluster", "kubernetes_namespace", "kubernetes_pod_name", "kubernetes_pod_uid"] :
        !contains([for field in signalfx_time_chart.k8s_memory_usage_bytes.legend_options_fields : field.property if field.enabled], property)
      ])
    )
    error_message = "K8S runner charts must keep ARC controller availability, active pod, top CPU, memory percentage, and tenant pod status behavior."
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

  assert {
    condition = (
      strcontains(signalfx_time_chart.k8s_pod_phase_trend.program_text, "alerts(detector_id='k8s-no-data-detector-id')")
      && strcontains(signalfx_time_chart.k8s_pod_phase_trend.program_text, "alerts(detector_id='tenant-pending-detector-id')")
      && length(regexall("alerts\\(detector_id=", signalfx_time_chart.k8s_pod_phase_trend.program_text)) == 2
    )
    error_message = "The pod-phase trend must link the Kubernetes telemetry and tenant pending-pod detectors."
  }
}

run "runner_k8s_dashboard_wiring_contract" {
  command = plan

  assert {
    condition = (
      signalfx_dashboard.runner_k8s.name == "Forge Tenant - K8S Runners"
      && signalfx_dashboard.runner_k8s.dashboard_group == "forge-dashboard-group"
      && length(signalfx_dashboard.runner_k8s.variable[0].values) == 0
      && !signalfx_dashboard.runner_k8s.variable[0].value_required
      && signalfx_dashboard.runner_k8s.variable[0].values_suggested == toset(["tenant-a", "tenant-b"])
      && signalfx_dashboard.runner_k8s.variable[0].restricted_suggestions
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
