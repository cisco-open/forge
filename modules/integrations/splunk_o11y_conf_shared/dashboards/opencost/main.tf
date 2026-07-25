locals {
  opencost_tenant_namespace_filter = length(var.tenant_names) > 0 ? join(" or ", [
    for namespace in sort(var.tenant_names) : "filter('namespace', '${namespace}')"
  ]) : "filter('namespace', '__forge_tenant_scope_not_configured__')"
  opencost_cluster_variables = [
    for var_def in var.dynamic_variables : var_def
    if var_def.property == "k8s.cluster.name"
  ]
  opencost_cluster_variable = length(local.opencost_cluster_variables) > 0 ? local.opencost_cluster_variables[0] : null
  opencost_cluster_names = distinct(flatten([
    for var_def in local.opencost_cluster_variables : var_def.values_suggested
  ]))
  opencost_cluster_filter = length(local.opencost_cluster_names) > 0 ? join(" or ", [
    # OpenCost emits the Helm defaultClusterId value as cluster_id. The
    # Kubernetes dashboard variable supplies the same cluster names, but its
    # k8s.cluster.name property is not guaranteed to be attached to Prometheus
    # metrics by the collector.
    for cluster_name in local.opencost_cluster_names : "filter('cluster_id', '${cluster_name}')"
  ]) : "filter('cluster_id', '__forge_cluster_scope_not_configured__')"
}

resource "signalfx_list_chart" "tenant_hourly_compute_cost" {
  name        = "Tenant hourly compute cost"
  description = "Estimates current OpenCost CPU and memory allocation cost by tenant namespace."

  program_text = <<-EOF
cpu_allocation = data('container_cpu_allocation', filter=(${local.opencost_tenant_namespace_filter}) and (${local.opencost_cluster_filter}) and filter('node', '*')).sum(by=['k8s.cluster.name', 'namespace', 'node'])
cpu_price = data('node_cpu_hourly_cost', filter=(${local.opencost_cluster_filter}) and filter('node', '*')).mean(by=['k8s.cluster.name', 'node'])
cpu_cost = (cpu_allocation * cpu_price).sum(by=['namespace'])

memory_allocation = data('container_memory_allocation_bytes', filter=(${local.opencost_tenant_namespace_filter}) and (${local.opencost_cluster_filter}) and filter('node', '*')).sum(by=['k8s.cluster.name', 'namespace', 'node']).scale(0.0000000009313225746154785)
memory_price = data('node_ram_hourly_cost', filter=(${local.opencost_cluster_filter}) and filter('node', '*')).mean(by=['k8s.cluster.name', 'node'])
memory_cost = (memory_allocation * memory_price).sum(by=['namespace'])

A = (cpu_cost + memory_cost).publish(label='A')
EOF

  sort_by = "-value"

  hide_missing_values     = true
  max_precision           = 4
  secondary_visualization = "Sparkline"
  unit_prefix             = "Metric"

  legend_options_fields {
    enabled  = true
    property = "namespace"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_metric"
  }

  viz_options {
    display_name = "USD/hour"
    label        = "A"
  }
}

resource "signalfx_list_chart" "tenant_monthly_compute_run_rate" {
  name        = "Tenant monthly compute run rate"
  description = "Projects current OpenCost CPU and memory allocation cost to a 730-hour month by tenant namespace."

  program_text = <<-EOF
cpu_allocation = data('container_cpu_allocation', filter=(${local.opencost_tenant_namespace_filter}) and (${local.opencost_cluster_filter}) and filter('node', '*')).sum(by=['k8s.cluster.name', 'namespace', 'node'])
cpu_price = data('node_cpu_hourly_cost', filter=(${local.opencost_cluster_filter}) and filter('node', '*')).mean(by=['k8s.cluster.name', 'node'])
cpu_cost = (cpu_allocation * cpu_price).sum(by=['namespace'])

memory_allocation = data('container_memory_allocation_bytes', filter=(${local.opencost_tenant_namespace_filter}) and (${local.opencost_cluster_filter}) and filter('node', '*')).sum(by=['k8s.cluster.name', 'namespace', 'node']).scale(0.0000000009313225746154785)
memory_price = data('node_ram_hourly_cost', filter=(${local.opencost_cluster_filter}) and filter('node', '*')).mean(by=['k8s.cluster.name', 'node'])
memory_cost = (memory_allocation * memory_price).sum(by=['namespace'])

A = (cpu_cost + memory_cost).scale(730).publish(label='A')
EOF

  sort_by = "-value"

  hide_missing_values     = true
  max_precision           = 2
  secondary_visualization = "Sparkline"
  unit_prefix             = "Metric"

  legend_options_fields {
    enabled  = true
    property = "namespace"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_metric"
  }

  viz_options {
    display_name = "USD/month"
    label        = "A"
  }
}

resource "signalfx_time_chart" "tenant_compute_cost_trend" {
  name        = "Tenant compute cost trend"
  description = "Tracks OpenCost CPU and memory allocation cost by tenant namespace over time."

  program_text = <<-EOF
cpu_allocation = data('container_cpu_allocation', filter=(${local.opencost_tenant_namespace_filter}) and (${local.opencost_cluster_filter}) and filter('node', '*')).sum(by=['k8s.cluster.name', 'namespace', 'node'])
cpu_price = data('node_cpu_hourly_cost', filter=(${local.opencost_cluster_filter}) and filter('node', '*')).mean(by=['k8s.cluster.name', 'node'])
cpu_cost = (cpu_allocation * cpu_price).sum(by=['namespace'])

memory_allocation = data('container_memory_allocation_bytes', filter=(${local.opencost_tenant_namespace_filter}) and (${local.opencost_cluster_filter}) and filter('node', '*')).sum(by=['k8s.cluster.name', 'namespace', 'node']).scale(0.0000000009313225746154785)
memory_price = data('node_ram_hourly_cost', filter=(${local.opencost_cluster_filter}) and filter('node', '*')).mean(by=['k8s.cluster.name', 'node'])
memory_cost = (memory_allocation * memory_price).sum(by=['namespace'])

A = (cpu_cost + memory_cost).publish(label='A')
EOF

  plot_type                 = "AreaChart"
  axes_precision            = 4
  on_chart_legend_dimension = "namespace"
  unit_prefix               = "Metric"

  axis_left {
    label = "USD/hour"
  }

  histogram_options {
    color_theme = "gold"
  }

  viz_options {
    display_name = "USD/hour"
    label        = "A"
  }
}

resource "signalfx_time_chart" "tenant_cpu_cost" {
  name        = "Tenant CPU cost"
  description = "Tracks OpenCost CPU allocation cost by tenant namespace."

  program_text = <<-EOF
cpu_allocation = data('container_cpu_allocation', filter=(${local.opencost_tenant_namespace_filter}) and (${local.opencost_cluster_filter}) and filter('node', '*')).sum(by=['k8s.cluster.name', 'namespace', 'node'])
cpu_price = data('node_cpu_hourly_cost', filter=(${local.opencost_cluster_filter}) and filter('node', '*')).mean(by=['k8s.cluster.name', 'node'])
A = (cpu_allocation * cpu_price).sum(by=['namespace']).publish(label='A')
EOF

  plot_type                 = "AreaChart"
  axes_precision            = 4
  on_chart_legend_dimension = "namespace"
  unit_prefix               = "Metric"

  axis_left {
    label = "USD/hour"
  }

  histogram_options {
    color_theme = "gold"
  }

  viz_options {
    display_name = "CPU USD/hour"
    label        = "A"
  }
}

resource "signalfx_time_chart" "tenant_memory_cost" {
  name        = "Tenant memory cost"
  description = "Tracks OpenCost memory allocation cost by tenant namespace."

  program_text = <<-EOF
memory_allocation = data('container_memory_allocation_bytes', filter=(${local.opencost_tenant_namespace_filter}) and (${local.opencost_cluster_filter}) and filter('node', '*')).sum(by=['k8s.cluster.name', 'namespace', 'node']).scale(0.0000000009313225746154785)
memory_price = data('node_ram_hourly_cost', filter=(${local.opencost_cluster_filter}) and filter('node', '*')).mean(by=['k8s.cluster.name', 'node'])
A = (memory_allocation * memory_price).sum(by=['namespace']).publish(label='A')
EOF

  plot_type                 = "AreaChart"
  axes_precision            = 4
  on_chart_legend_dimension = "namespace"
  unit_prefix               = "Metric"

  axis_left {
    label = "USD/hour"
  }

  histogram_options {
    color_theme = "gold"
  }

  viz_options {
    display_name = "Memory USD/hour"
    label        = "A"
  }
}

resource "signalfx_list_chart" "top_pod_compute_cost" {
  name        = "Top pod compute cost"
  description = "Ranks pods by current OpenCost CPU and memory allocation cost."

  program_text = <<-EOF
cpu_allocation = data('container_cpu_allocation', filter=(${local.opencost_tenant_namespace_filter}) and (${local.opencost_cluster_filter}) and filter('node', '*') and filter('pod', '*')).sum(by=['k8s.cluster.name', 'namespace', 'pod', 'node'])
cpu_price = data('node_cpu_hourly_cost', filter=(${local.opencost_cluster_filter}) and filter('node', '*')).mean(by=['k8s.cluster.name', 'node'])
cpu_cost = (cpu_allocation * cpu_price).sum(by=['namespace', 'pod'])

memory_allocation = data('container_memory_allocation_bytes', filter=(${local.opencost_tenant_namespace_filter}) and (${local.opencost_cluster_filter}) and filter('node', '*') and filter('pod', '*')).sum(by=['k8s.cluster.name', 'namespace', 'pod', 'node']).scale(0.0000000009313225746154785)
memory_price = data('node_ram_hourly_cost', filter=(${local.opencost_cluster_filter}) and filter('node', '*')).mean(by=['k8s.cluster.name', 'node'])
memory_cost = (memory_allocation * memory_price).sum(by=['namespace', 'pod'])

A = (cpu_cost + memory_cost).top(count=20).publish(label='A')
EOF

  sort_by = "-value"

  hide_missing_values     = true
  max_precision           = 4
  secondary_visualization = "Sparkline"
  unit_prefix             = "Metric"

  legend_options_fields {
    enabled  = true
    property = "namespace"
  }
  legend_options_fields {
    enabled  = true
    property = "pod"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_metric"
  }

  viz_options {
    display_name = "USD/hour"
    label        = "A"
  }
}

resource "terraform_data" "dashboard_parent" {
  triggers_replace = var.dashboard_group
}

resource "signalfx_dashboard" "opencost" {
  name            = "Forge Billing and Cost - OpenCost"
  description     = "OpenCost Kubernetes CPU and memory allocation estimates by Forge tenant namespace; these are not AWS billing charges."
  dashboard_group = var.dashboard_group

  lifecycle {
    replace_triggered_by = [
      terraform_data.dashboard_parent,
    ]
  }

  time_range = "-24h"

  variable {
    property               = "namespace"
    alias                  = "ForgeCICD Tenant Name"
    description            = ""
    values                 = []
    value_required         = false
    values_suggested       = sort(var.tenant_names)
    restricted_suggestions = true
  }

  variable {
    property               = "cluster_id"
    alias                  = "Forge Cluster"
    description            = ""
    values                 = local.opencost_cluster_variable == null ? [] : local.opencost_cluster_variable.values
    value_required         = local.opencost_cluster_variable == null ? false : local.opencost_cluster_variable.value_required
    values_suggested       = local.opencost_cluster_variable == null ? [] : local.opencost_cluster_variable.values_suggested
    restricted_suggestions = local.opencost_cluster_variable == null ? false : local.opencost_cluster_variable.restricted_suggestions
  }

  chart {
    chart_id = signalfx_list_chart.tenant_hourly_compute_cost.id
    row      = 0
    column   = 0
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.tenant_monthly_compute_run_rate.id
    row      = 0
    column   = 4
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.top_pod_compute_cost.id
    row      = 0
    column   = 8
    width    = 4
    height   = 2
  }

  chart {
    chart_id = signalfx_time_chart.tenant_compute_cost_trend.id
    row      = 1
    column   = 0
    width    = 8
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.tenant_cpu_cost.id
    row      = 2
    column   = 0
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.tenant_memory_cost.id
    row      = 2
    column   = 6
    width    = 6
    height   = 1
  }
}
