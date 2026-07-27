locals {
  detector_tags = ["forgecicd", "k8s", "terraform"]

  k8s_dashboard_cluster_names = distinct(flatten([
    for var_def in var.dynamic_variables : var_def.values_suggested
    if var_def.property == "k8s.cluster.name"
  ]))
  k8s_cluster_filter = length(local.k8s_dashboard_cluster_names) > 0 ? join(" or ", [
    for cluster_name in local.k8s_dashboard_cluster_names : "filter('k8s.cluster.name', '${cluster_name}')"
  ]) : "filter('k8s.cluster.name', '__forge_cluster_scope_not_configured__')"

  k8s_tenant_namespace_filter = length(var.tenant_names) > 0 ? join(" or ", [
    for namespace in sort(var.tenant_names) : "filter('k8s.namespace.name', '${namespace}')"
  ]) : "filter('k8s.namespace.name', '*')"
  k8s_tenant_filter = "(${local.k8s_cluster_filter}) and (${local.k8s_tenant_namespace_filter})"

  k8s_platform_namespace_filter = join(" or ", [
    for namespace in var.k8s_platform_namespaces : "filter('k8s.namespace.name', '${namespace}')"
  ])
  k8s_platform_filter = "(${local.k8s_cluster_filter}) and (${local.k8s_platform_namespace_filter})"

  k8s_otel_collector_filter = "(${local.k8s_cluster_filter}) and filter('k8s.namespace.name', '${var.k8s_otel_collector_config.namespace}') and filter('k8s.pod.name', '${var.k8s_otel_collector_config.pod_name_filter}')"
}

resource "signalfx_detector" "k8s_otel_no_data" {
  name        = "${var.detector_name_prefix} K8S OTel no data"
  description = "Warns when Kubernetes pod phase metrics stop arriving from a Forge cluster. Investigate collector and ingestion health; missing telemetry alone does not prove Forge service impact."
  max_delay   = 120
  tags        = local.detector_tags
  teams       = [var.team]
  time_range  = 3600

  program_text = <<-EOF
pod_phase_value = data('k8s.pod.phase', filter=(${local.k8s_cluster_filter}), rollup='latest').sum(by=['k8s.cluster.name']).fill(value=0, duration='${var.k8s_detector_config.otel_no_data_fill_duration}')
detect(when(pod_phase_value < 1, '${var.k8s_detector_config.otel_no_data_duration}')).publish('No Kubernetes pod metrics')
EOF

  rule {
    description   = "No Kubernetes pod metrics for ${var.k8s_detector_config.otel_no_data_duration}"
    severity      = "Warning"
    detect_label  = "No Kubernetes pod metrics"
    notifications = var.detector_notifications
  }
}

resource "signalfx_detector" "k8s_otel_collector_health" {
  name        = "${var.detector_name_prefix} K8S Splunk OTel collector health"
  description = "Detects sustained Splunk OpenTelemetry Collector unavailability or degradation by cluster. Restore collector capacity and confirm metric ingestion before treating downstream no-data as a Forge outage."
  max_delay   = 120
  tags        = local.detector_tags
  teams       = [var.team]
  time_range  = 3600

  program_text = <<-EOF
running_collector_pods = data('k8s.pod.phase', filter=(${local.k8s_otel_collector_filter}), rollup='latest').between(1.5, 2.5, low_inclusive=True, high_inclusive=True).count(by=['k8s.cluster.name']).fill(value=0, duration='${var.k8s_otel_collector_config.stale_metrics_duration}')
pending_collector_pods = data('k8s.pod.phase', filter=(${local.k8s_otel_collector_filter}), rollup='latest').between(0, 1.5, low_inclusive=True, high_inclusive=True).sum(by=['k8s.cluster.name']).fill(value=0, duration='${var.k8s_otel_collector_config.pod_issue_duration}')
unhealthy_collector_pods = data('k8s.pod.phase', filter=(${local.k8s_otel_collector_filter}), rollup='latest').between(3.5, 5.5, low_inclusive=True, high_inclusive=True).sum(by=['k8s.cluster.name']).fill(value=0, duration='${var.k8s_otel_collector_config.pod_issue_duration}')
collector_restarts = data('k8s.container.restarts', filter=(${local.k8s_otel_collector_filter}), rollup='latest').delta().sum(over='${var.k8s_otel_collector_config.restart_duration}').sum(by=['k8s.cluster.name']).fill(value=0, duration='${var.k8s_otel_collector_config.restart_duration}')
detect(when(running_collector_pods < ${var.k8s_otel_collector_config.min_running_pods}, '${var.k8s_otel_collector_config.no_running_duration}')).publish('No running Splunk OTel collector pods')
detect(when(pending_collector_pods > 0, '${var.k8s_otel_collector_config.pod_issue_duration}')).publish('Splunk OTel collector pod pending')
detect(when(unhealthy_collector_pods > 0, '${var.k8s_otel_collector_config.pod_issue_duration}')).publish('Splunk OTel collector pod failed or unknown')
detect(when(collector_restarts > ${var.k8s_otel_collector_config.restart_threshold})).publish('Splunk OTel collector container restarting')
EOF

  rule {
    description   = "No running Splunk OpenTelemetry Collector pods for ${var.k8s_otel_collector_config.no_running_duration}"
    severity      = "Major"
    detect_label  = "No running Splunk OTel collector pods"
    notifications = var.detector_notifications
  }

  rule {
    description   = "Splunk OpenTelemetry Collector pod pending for ${var.k8s_otel_collector_config.pod_issue_duration}"
    severity      = "Warning"
    detect_label  = "Splunk OTel collector pod pending"
    notifications = var.detector_notifications
  }

  rule {
    description   = "Splunk OpenTelemetry Collector pod failed or unknown for ${var.k8s_otel_collector_config.pod_issue_duration}"
    severity      = "Major"
    detect_label  = "Splunk OTel collector pod failed or unknown"
    notifications = var.detector_notifications
  }

  rule {
    description   = "Splunk OpenTelemetry Collector container restarts for ${var.k8s_otel_collector_config.restart_duration}"
    severity      = "Warning"
    detect_label  = "Splunk OTel collector container restarting"
    notifications = var.detector_notifications
  }
}

resource "signalfx_detector" "k8s_tenant_pods_pending" {
  name        = "${var.detector_name_prefix} K8S tenant pods pending"
  description = "Warns when tenant runner pods remain Pending, grouped by tenant and cluster. Check cluster capacity, node pressure, quotas, and scheduling events before escalating."
  max_delay   = 120
  tags        = local.detector_tags
  teams       = [var.team]
  time_range  = 3600

  program_text = <<-EOF
pending_pods = data('k8s.pod.phase', filter=(${local.k8s_tenant_filter}), rollup='latest').between(0, 1.5, low_inclusive=True, high_inclusive=True).sum(by=['k8s.cluster.name', 'k8s.namespace.name']).fill(value=0, duration='${var.k8s_detector_config.pending_pods_duration}')
detect(when(pending_pods > ${var.k8s_detector_config.pending_pods_threshold}, '${var.k8s_detector_config.pending_pods_duration}')).publish('Tenant pod pending')
EOF

  rule {
    description   = "Tenant pod pending for ${var.k8s_detector_config.pending_pods_duration}"
    severity      = "Warning"
    detect_label  = "Tenant pod pending"
    notifications = var.tenant_pods_pending_notifications == null ? var.detector_notifications : var.tenant_pods_pending_notifications
  }
}

resource "signalfx_detector" "k8s_platform_pods_unhealthy" {
  name        = "${var.detector_name_prefix} K8S platform pods unhealthy"
  description = "Detects sustained failed or unknown pods and repeated container restarts in Forge platform namespaces, grouped by cluster and namespace."
  max_delay   = 120
  tags        = local.detector_tags
  teams       = [var.team]
  time_range  = 3600

  program_text = <<-EOF
platform_failed_pods = data('k8s.pod.phase', filter=(${local.k8s_platform_filter}), rollup='latest').between(3.5, 5.5, low_inclusive=True, high_inclusive=True).sum(by=['k8s.cluster.name', 'k8s.namespace.name']).fill(value=0, duration='${var.k8s_detector_config.platform_pods_duration}')
platform_container_restarts = data('k8s.container.restarts', filter=(${local.k8s_platform_filter}) and filter('k8s.container.name', '*'), rollup='latest').max(by=['k8s.cluster.name', 'k8s.namespace.name', 'k8s.pod.name', 'k8s.container.name']).delta().sum(over='${var.k8s_detector_config.container_restarts_duration}').sum(by=['k8s.cluster.name', 'k8s.namespace.name']).fill(value=0, duration='${var.k8s_detector_config.container_restarts_duration}')
detect(when(platform_failed_pods > ${var.k8s_detector_config.platform_unhealthy_threshold}, '${var.k8s_detector_config.platform_pods_duration}')).publish('Platform pod failed or unknown')
detect(when(platform_container_restarts > ${var.k8s_detector_config.container_restarts_threshold})).publish('Platform container restarting')
EOF

  rule {
    description   = "Platform pod failed or unknown for ${var.k8s_detector_config.platform_pods_duration}"
    severity      = "Major"
    detect_label  = "Platform pod failed or unknown"
    notifications = var.detector_notifications
  }

  rule {
    description   = "Platform container restarts above ${var.k8s_detector_config.container_restarts_threshold} for ${var.k8s_detector_config.container_restarts_duration}"
    severity      = "Warning"
    detect_label  = "Platform container restarting"
    notifications = var.detector_notifications
  }
}
