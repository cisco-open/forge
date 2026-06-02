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
    for namespace in var.tenant_names : "filter('k8s.namespace.name', '${namespace}')"
  ]) : "filter('k8s.namespace.name', '*')"
  k8s_tenant_filter = "(${local.k8s_cluster_filter}) and (${local.k8s_tenant_namespace_filter})"

  k8s_platform_namespace_filter = join(" or ", [
    for namespace in var.k8s_platform_namespaces : "filter('k8s.namespace.name', '${namespace}')"
  ])
  k8s_platform_filter = "(${local.k8s_cluster_filter}) and (${local.k8s_platform_namespace_filter})"

  k8s_other_namespace_exclusions = distinct(concat(var.k8s_platform_namespaces, [var.k8s_otel_collector_config.namespace], var.tenant_names))
  k8s_other_namespace_filter     = "(${local.k8s_cluster_filter}) and filter('k8s.namespace.name', '*') and not filter('k8s.namespace.name', '${join("', '", local.k8s_other_namespace_exclusions)}')"

  k8s_otel_collector_filter = "(${local.k8s_cluster_filter}) and filter('k8s.namespace.name', '${var.k8s_otel_collector_config.namespace}') and filter('k8s.pod.name', '${var.k8s_otel_collector_config.pod_name_filter}')"
}

resource "signalfx_detector" "k8s_otel_no_data" {
  name        = "${var.detector_name_prefix} K8S OTel no data"
  description = "Detects when Kubernetes pod phase metrics stop arriving from a Forge cluster, which usually means the Splunk OpenTelemetry Collector is down or not sending data."
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
    severity      = "Critical"
    detect_label  = "No Kubernetes pod metrics"
    notifications = var.detector_notifications
  }
}

resource "signalfx_detector" "k8s_otel_collector_health" {
  name        = "${var.detector_name_prefix} K8S Splunk OTel collector health"
  description = "Detects missing, pending, failed, unknown, or restarting Splunk OpenTelemetry Collector pods. These issues can mean the collector is not installed, is unhealthy, or is unable to send Kubernetes metrics."
  max_delay   = 120
  tags        = local.detector_tags
  teams       = [var.team]
  time_range  = 3600

  program_text = <<-EOF
running_collector_pods = data('k8s.pod.phase', filter=(${local.k8s_otel_collector_filter}), rollup='latest').between(1.5, 2.5, low_inclusive=True, high_inclusive=True).count(by=['k8s.cluster.name']).fill(value=0, duration='${var.k8s_otel_collector_config.stale_metrics_duration}')
pending_collector_pods = data('k8s.pod.phase', filter=(${local.k8s_otel_collector_filter}), rollup='latest').between(0, 1.5, low_inclusive=True, high_inclusive=True).sum(by=['k8s.cluster.name', 'k8s.namespace.name', 'k8s.pod.name'])
unhealthy_collector_pods = data('k8s.pod.phase', filter=(${local.k8s_otel_collector_filter}), rollup='latest').between(3.5, 5.5, low_inclusive=True, high_inclusive=True).sum(by=['k8s.cluster.name', 'k8s.namespace.name', 'k8s.pod.name'])
collector_restarts = data('k8s.container.restarts', filter=(${local.k8s_otel_collector_filter}), rollup='latest').sum(by=['k8s.cluster.name', 'k8s.namespace.name', 'k8s.pod.name', 'k8s.container.name'])
detect(when(running_collector_pods < ${var.k8s_otel_collector_config.min_running_pods}, '${var.k8s_otel_collector_config.no_running_duration}')).publish('No running Splunk OTel collector pods')
detect(when(pending_collector_pods > 0, '${var.k8s_otel_collector_config.pod_issue_duration}')).publish('Splunk OTel collector pod pending')
detect(when(unhealthy_collector_pods > 0, '${var.k8s_otel_collector_config.pod_issue_duration}')).publish('Splunk OTel collector pod failed or unknown')
detect(when(collector_restarts > ${var.k8s_otel_collector_config.restart_threshold}, '${var.k8s_otel_collector_config.restart_duration}')).publish('Splunk OTel collector container restarting')
EOF

  rule {
    description   = "No running Splunk OpenTelemetry Collector pods for ${var.k8s_otel_collector_config.no_running_duration}"
    severity      = "Critical"
    detect_label  = "No running Splunk OTel collector pods"
    notifications = var.detector_notifications
  }

  rule {
    description   = "Splunk OpenTelemetry Collector pod pending for ${var.k8s_otel_collector_config.pod_issue_duration}"
    severity      = "Major"
    detect_label  = "Splunk OTel collector pod pending"
    notifications = var.detector_notifications
  }

  rule {
    description   = "Splunk OpenTelemetry Collector pod failed or unknown for ${var.k8s_otel_collector_config.pod_issue_duration}"
    severity      = "Critical"
    detect_label  = "Splunk OTel collector pod failed or unknown"
    notifications = var.detector_notifications
  }

  rule {
    description   = "Splunk OpenTelemetry Collector container restarts for ${var.k8s_otel_collector_config.restart_duration}"
    severity      = "Major"
    detect_label  = "Splunk OTel collector container restarting"
    notifications = var.detector_notifications
  }
}

resource "signalfx_detector" "k8s_other_namespace_pods_unhealthy" {
  name        = "${var.detector_name_prefix} K8S other namespace pods unhealthy"
  description = "Detects pending, failed, unknown, or restarting pods in namespaces outside the platform and Splunk OpenTelemetry Collector namespaces."
  max_delay   = 120
  tags        = local.detector_tags
  teams       = [var.team]
  time_range  = 3600

  program_text = <<-EOF
other_pending_pods = data('k8s.pod.phase', filter=(${local.k8s_other_namespace_filter}), rollup='latest').between(0, 1.5, low_inclusive=True, high_inclusive=True).sum(by=['k8s.cluster.name', 'k8s.namespace.name', 'k8s.pod.name'])
other_unhealthy_pods = data('k8s.pod.phase', filter=(${local.k8s_other_namespace_filter}), rollup='latest').between(3.5, 5.5, low_inclusive=True, high_inclusive=True).sum(by=['k8s.cluster.name', 'k8s.namespace.name', 'k8s.pod.name'])
other_container_restarts = data('k8s.container.restarts', filter=(${local.k8s_other_namespace_filter}), rollup='latest').sum(by=['k8s.cluster.name', 'k8s.namespace.name', 'k8s.pod.name', 'k8s.container.name'])
detect(when(other_pending_pods > ${var.k8s_detector_config.pending_pods_threshold}, '${var.k8s_detector_config.pending_pods_duration}')).publish('Other namespace pod pending')
detect(when(other_unhealthy_pods > ${var.k8s_detector_config.failed_pods_threshold}, '${var.k8s_detector_config.failed_pods_duration}')).publish('Other namespace pod failed or unknown')
detect(when(other_container_restarts > ${var.k8s_detector_config.container_restarts_threshold}, '${var.k8s_detector_config.container_restarts_duration}')).publish('Other namespace container restarting')
EOF

  rule {
    description   = "Pod pending outside platform namespaces for ${var.k8s_detector_config.pending_pods_duration}"
    severity      = "Warning"
    detect_label  = "Other namespace pod pending"
    notifications = var.detector_notifications
  }

  rule {
    description   = "Pod failed or unknown outside platform namespaces for ${var.k8s_detector_config.failed_pods_duration}"
    severity      = "Major"
    detect_label  = "Other namespace pod failed or unknown"
    notifications = var.detector_notifications
  }

  rule {
    description   = "Container restarts outside platform namespaces for ${var.k8s_detector_config.container_restarts_duration}"
    severity      = "Major"
    detect_label  = "Other namespace container restarting"
    notifications = var.detector_notifications
  }
}

resource "signalfx_detector" "k8s_tenant_pods_pending" {
  name        = "${var.detector_name_prefix} K8S tenant pods pending"
  description = "Detects tenant pods stuck in Pending, which is the main signal for pods that are not scheduling."
  max_delay   = 120
  tags        = local.detector_tags
  teams       = [var.team]
  time_range  = 3600

  program_text = <<-EOF
pending_pods = data('k8s.pod.phase', filter=(${local.k8s_tenant_filter}), rollup='latest').between(0, 1.5, low_inclusive=True, high_inclusive=True).sum(by=['k8s.cluster.name', 'k8s.namespace.name', 'k8s.pod.name'])
detect(when(pending_pods > ${var.k8s_detector_config.pending_pods_threshold}, '${var.k8s_detector_config.pending_pods_duration}')).publish('Tenant pod pending')
EOF

  rule {
    description   = "Tenant pod pending for ${var.k8s_detector_config.pending_pods_duration}"
    severity      = "Warning"
    detect_label  = "Tenant pod pending"
    notifications = var.detector_notifications
  }
}

resource "signalfx_detector" "k8s_tenant_pods_failed" {
  name        = "${var.detector_name_prefix} K8S tenant pods failed"
  description = "Detects tenant pods in Failed phase, grouped by cluster, namespace, and pod."
  max_delay   = 120
  tags        = local.detector_tags
  teams       = [var.team]
  time_range  = 3600

  program_text = <<-EOF
failed_pods = data('k8s.pod.phase', filter=(${local.k8s_tenant_filter}), rollup='latest').between(3.5, 4.5, low_inclusive=True, high_inclusive=True).sum(by=['k8s.cluster.name', 'k8s.namespace.name', 'k8s.pod.name'])
detect(when(failed_pods > ${var.k8s_detector_config.failed_pods_threshold}, '${var.k8s_detector_config.failed_pods_duration}')).publish('Tenant pod failed')
EOF

  rule {
    description   = "Tenant pod failed for ${var.k8s_detector_config.failed_pods_duration}"
    severity      = "Major"
    detect_label  = "Tenant pod failed"
    notifications = var.detector_notifications
  }
}

resource "signalfx_detector" "k8s_tenant_container_restarts" {
  name        = "${var.detector_name_prefix} K8S tenant container restarts"
  description = "Detects restarted containers in tenant namespaces, grouped by cluster, namespace, pod, and container."
  max_delay   = 120
  tags        = local.detector_tags
  teams       = [var.team]
  time_range  = 3600

  program_text = <<-EOF
container_restarts = data('k8s.container.restarts', filter=(${local.k8s_tenant_filter}), rollup='latest').sum(by=['k8s.cluster.name', 'k8s.namespace.name', 'k8s.pod.name', 'k8s.container.name'])
detect(when(container_restarts > ${var.k8s_detector_config.container_restarts_threshold}, '${var.k8s_detector_config.container_restarts_duration}')).publish('Tenant container restarting')
EOF

  rule {
    description   = "Tenant container restarts for ${var.k8s_detector_config.container_restarts_duration}"
    severity      = "Major"
    detect_label  = "Tenant container restarting"
    notifications = var.detector_notifications
  }
}

resource "signalfx_detector" "k8s_platform_pods_unhealthy" {
  name        = "${var.detector_name_prefix} K8S platform pods unhealthy"
  description = "Detects unhealthy platform pods in kube-system, Karpenter, Calico, and Tigera namespaces."
  max_delay   = 120
  tags        = local.detector_tags
  teams       = [var.team]
  time_range  = 3600

  program_text = <<-EOF
platform_pending_pods = data('k8s.pod.phase', filter=(${local.k8s_platform_filter}), rollup='latest').between(0, 1.5, low_inclusive=True, high_inclusive=True).sum(by=['k8s.cluster.name', 'k8s.namespace.name', 'k8s.pod.name'])
platform_failed_pods = data('k8s.pod.phase', filter=(${local.k8s_platform_filter}), rollup='latest').between(3.5, 5.5, low_inclusive=True, high_inclusive=True).sum(by=['k8s.cluster.name', 'k8s.namespace.name', 'k8s.pod.name'])
detect(when(platform_pending_pods > ${var.k8s_detector_config.platform_unhealthy_threshold}, '${var.k8s_detector_config.platform_pods_duration}')).publish('Platform pod pending')
detect(when(platform_failed_pods > ${var.k8s_detector_config.platform_unhealthy_threshold}, '${var.k8s_detector_config.platform_pods_duration}')).publish('Platform pod failed or unknown')
EOF

  rule {
    description   = "Platform pod pending for ${var.k8s_detector_config.platform_pods_duration}"
    severity      = "Critical"
    detect_label  = "Platform pod pending"
    notifications = var.detector_notifications
  }

  rule {
    description   = "Platform pod failed or unknown for ${var.k8s_detector_config.platform_pods_duration}"
    severity      = "Critical"
    detect_label  = "Platform pod failed or unknown"
    notifications = var.detector_notifications
  }
}
