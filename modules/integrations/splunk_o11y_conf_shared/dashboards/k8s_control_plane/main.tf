locals {
  k8s_cluster_variables = [
    for var_def in var.dynamic_variables : var_def
    if var_def.property == "k8s.cluster.name"
  ]
  k8s_cluster_names = distinct(flatten([
    for var_def in local.k8s_cluster_variables : var_def.values_suggested
  ]))
  k8s_cluster_filter = length(local.k8s_cluster_names) > 0 ? join(" or ", [
    for cluster_name in local.k8s_cluster_names : "filter('k8s.cluster.name', '${cluster_name}')"
  ]) : "filter('k8s.cluster.name', '__forge_cluster_scope_not_configured__')"

  k8s_platform_namespaces = distinct(concat(
    var.platform_namespaces,
    ["monitoring", "prometheus", "splunk-otel-collector"],
  ))
  k8s_platform_namespace_filter = length(local.k8s_platform_namespaces) > 0 ? join(" or ", [
    for namespace in sort(local.k8s_platform_namespaces) : "filter('k8s.namespace.name', '${namespace}')"
  ]) : "filter('k8s.namespace.name', '__forge_platform_scope_not_configured__')"
  k8s_platform_filter       = "(${local.k8s_cluster_filter}) and (${local.k8s_platform_namespace_filter})"
  k8s_otel_collector_filter = "(${local.k8s_cluster_filter}) and filter('k8s.namespace.name', 'splunk-otel-collector') and filter('k8s.pod.name', 'splunk-otel-collector*')"
}

resource "signalfx_time_chart" "platform_pod_health" {
  name        = "Platform pod health"
  description = "Shows running, pending, failed, and unknown pods in configured Kubernetes control-plane namespaces."

  program_text = <<-EOF
A = data('k8s.pod.phase', filter=(${local.k8s_platform_filter}), rollup='latest').between(1.5, 2.5, low_inclusive=True, high_inclusive=True).count(by=['k8s.cluster.name', 'k8s.namespace.name']).publish(label='Running')
B = data('k8s.pod.phase', filter=(${local.k8s_platform_filter}), rollup='latest').between(0, 1.5, low_inclusive=True, high_inclusive=True).count(by=['k8s.cluster.name', 'k8s.namespace.name']).publish(label='Pending')
C = data('k8s.pod.phase', filter=(${local.k8s_platform_filter}), rollup='latest').between(3.5, 5.5, low_inclusive=True, high_inclusive=True).count(by=['k8s.cluster.name', 'k8s.namespace.name']).publish(label='Failed or unknown')
EOF

  plot_type                 = "LineChart"
  axes_precision            = 0
  disable_sampling          = true
  on_chart_legend_dimension = "plot_label"
  time_range                = 900

  axis_left {
    label = "Platform pods"
  }

  legend_options_fields {
    enabled  = true
    property = "k8s.cluster.name"
  }
  legend_options_fields {
    enabled  = true
    property = "k8s.namespace.name"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_metric"
  }
}

resource "signalfx_time_chart" "otel_collector_pods" {
  name        = "Splunk OTel collector pod health"
  description = "Shows running, pending, failed, and unknown Splunk OpenTelemetry Collector pods."

  program_text = <<-EOF
A = data('k8s.pod.phase', filter=(${local.k8s_otel_collector_filter}), rollup='latest').between(1.5, 2.5, low_inclusive=True, high_inclusive=True).count(by=['k8s.cluster.name']).publish(label='Running')
B = data('k8s.pod.phase', filter=(${local.k8s_otel_collector_filter}), rollup='latest').between(0, 1.5, low_inclusive=True, high_inclusive=True).count(by=['k8s.cluster.name']).publish(label='Pending')
C = data('k8s.pod.phase', filter=(${local.k8s_otel_collector_filter}), rollup='latest').between(3.5, 5.5, low_inclusive=True, high_inclusive=True).count(by=['k8s.cluster.name']).publish(label='Failed or unknown')
EOF

  plot_type                 = "LineChart"
  axes_precision            = 0
  disable_sampling          = true
  on_chart_legend_dimension = "plot_label"
  time_range                = 900

  axis_left {
    label = "Collector pods"
  }
}

resource "signalfx_time_chart" "node_pressure" {
  name        = "Node pressure conditions"
  description = "Shows active PID, memory, disk, or network pressure conditions by Kubernetes node."

  program_text = <<-EOF
A = data('k8s.node.condition', filter=(${local.k8s_cluster_filter}) and (filter('condition', 'PIDPressure') or filter('condition', 'MemoryPressure') or filter('condition', 'DiskPressure') or filter('condition', 'NetworkUnavailable')), rollup='max').max(by=['k8s.cluster.name', 'k8s.node.name', 'condition']).above(0).publish(label='A')
EOF

  plot_type                 = "LineChart"
  axes_precision            = 0
  disable_sampling          = true
  on_chart_legend_dimension = "condition"
  time_range                = 86400

  axis_left {
    label = "Active condition"
  }

  viz_options {
    display_name = "Node pressure"
    label        = "A"
  }
}

resource "signalfx_time_chart" "otel_exporter_queue_utilization" {
  name        = "OTel exporter queue utilization"
  description = "Shows exporter queue size as a percentage of capacity. Sustained growth can precede telemetry loss."

  program_text = <<-EOF
queue_size = data('otelcol_exporter_queue_size', filter=(${local.k8s_otel_collector_filter}), rollup='latest').mean(by=['k8s.cluster.name', 'k8s.pod.name', 'exporter', 'data_type'])
queue_capacity = data('otelcol_exporter_queue_capacity', filter=(${local.k8s_otel_collector_filter}), rollup='latest').mean(by=['k8s.cluster.name', 'k8s.pod.name', 'exporter', 'data_type'])
queue_utilization = ((queue_size / queue_capacity) * 100).top(count=20).publish(label='A')
EOF

  plot_type                 = "LineChart"
  axes_precision            = 2
  disable_sampling          = true
  on_chart_legend_dimension = "exporter"
  time_range                = 86400

  axis_left {
    label     = "Percent"
    max_value = 100
    min_value = 0
  }

  viz_options {
    display_name = "OTel exporter queue utilization"
    label        = "A"
    value_suffix = "%"
  }
}

resource "signalfx_time_chart" "otel_telemetry_loss" {
  name        = "OTel refused and failed metric points"
  description = "Shows metric points refused or failed by receivers and errored by scrapers."

  program_text = <<-EOF
refused = data('otelcol_receiver_refused_metric_points', filter=(${local.k8s_otel_collector_filter}), rollup='rate').sum(by=['k8s.cluster.name', 'receiver']).publish(label='Refused')
failed = data('otelcol_receiver_failed_metric_points', filter=(${local.k8s_otel_collector_filter}), rollup='rate').sum(by=['k8s.cluster.name', 'receiver']).publish(label='Failed')
scraper_errors = data('otelcol_scraper_errored_metric_points', filter=(${local.k8s_otel_collector_filter}), rollup='rate').sum(by=['k8s.cluster.name', 'scraper']).publish(label='Scraper errors')
EOF

  plot_type                 = "ColumnChart"
  axes_precision            = 2
  disable_sampling          = true
  on_chart_legend_dimension = "plot_label"
  time_range                = 604800

  axis_left {
    label = "Metric points / sec"
  }
}

resource "signalfx_dashboard" "k8s_control_plane" {
  name            = "Forge Control Plane - Kubernetes"
  description     = "Forge Kubernetes platform pods, node pressure, and telemetry pipeline health."
  dashboard_group = var.dashboard_group

  dynamic "variable" {
    for_each = local.k8s_cluster_variables
    iterator = var_def

    content {
      property               = var_def.value.property
      alias                  = var_def.value.alias
      description            = var_def.value.description
      values                 = var_def.value.values
      value_required         = var_def.value.value_required
      values_suggested       = var_def.value.values_suggested
      restricted_suggestions = var_def.value.restricted_suggestions
    }
  }

  chart {
    chart_id = signalfx_time_chart.platform_pod_health.id
    row      = 0
    column   = 0
    width    = 12
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.otel_collector_pods.id
    row      = 1
    column   = 0
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.node_pressure.id
    row      = 1
    column   = 6
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.otel_exporter_queue_utilization.id
    row      = 2
    column   = 0
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.otel_telemetry_loss.id
    row      = 2
    column   = 6
    width    = 6
    height   = 1
  }
}
