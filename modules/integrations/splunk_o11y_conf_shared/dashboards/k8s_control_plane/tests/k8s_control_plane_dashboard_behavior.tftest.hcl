mock_provider "signalfx" {}

variables {
  dashboard_group     = "forge-dashboard-group"
  platform_namespaces = ["karpenter", "kube-system", "monitoring"]
  dynamic_variables = [
    {
      property               = "k8s.cluster.name"
      alias                  = "K8S Cluster"
      description            = "Limit by cluster"
      values                 = ["forge-euw1-dev"]
      value_required         = true
      values_suggested       = ["forge-euw1-dev", "forge-use1-prod"]
      restricted_suggestions = true
    },
    {
      property               = "k8s.namespace.name"
      alias                  = "Namespace"
      description            = "Must not be copied to the control-plane dashboard"
      values                 = []
      value_required         = false
      values_suggested       = ["tenant-a"]
      restricted_suggestions = true
    },
  ]
}

run "k8s_control_plane_dashboard_contract" {
  command = plan

  assert {
    condition = (
      signalfx_dashboard.k8s_control_plane.name == "Forge Control Plane - Kubernetes"
      && signalfx_dashboard.k8s_control_plane.dashboard_group == "forge-dashboard-group"
      && length(signalfx_dashboard.k8s_control_plane.variable) == 1
      && signalfx_dashboard.k8s_control_plane.variable[0].property == "k8s.cluster.name"
      && length(signalfx_dashboard.k8s_control_plane.chart) == 5
    )
    error_message = "K8S control-plane dashboard must use only the cluster selector and wire all platform charts."
  }

  assert {
    condition = (
      strcontains(signalfx_time_chart.platform_pod_health.program_text, "filter('k8s.namespace.name', 'karpenter')")
      && strcontains(signalfx_time_chart.platform_pod_health.program_text, "filter('k8s.namespace.name', 'kube-system')")
      && strcontains(signalfx_time_chart.platform_pod_health.program_text, "filter('k8s.namespace.name', 'monitoring')")
      && strcontains(signalfx_time_chart.platform_pod_health.program_text, "filter('k8s.namespace.name', 'prometheus')")
      && strcontains(signalfx_time_chart.platform_pod_health.program_text, "filter('k8s.namespace.name', 'splunk-otel-collector')")
      && strcontains(signalfx_time_chart.node_pressure.program_text, "k8s.node.condition")
      && strcontains(signalfx_time_chart.node_pressure.program_text, "rollup='max'")
      && strcontains(signalfx_time_chart.node_pressure.program_text, ".max(by=['k8s.cluster.name', 'k8s.node.name', 'condition']).above(0)")
      && one(signalfx_time_chart.node_pressure.viz_options).display_name == "Node pressure"
      && strcontains(signalfx_time_chart.otel_exporter_queue_utilization.program_text, "otelcol_exporter_queue_capacity")
      && one(signalfx_time_chart.otel_exporter_queue_utilization.viz_options).display_name == "OTel exporter queue utilization"
      && strcontains(signalfx_time_chart.otel_telemetry_loss.program_text, "otelcol_receiver_refused_metric_points")
    )
    error_message = "K8S control-plane charts must cover configured platform namespaces, node pressure, and OTel pipeline health."
  }
}
