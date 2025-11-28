resource "signalfx_single_value_chart" "k8s_available_pods_by_deployments" {
  name        = "# Available pods by deployments"
  description = "Number of pods ready by deployments"

  program_text = "A = data('k8s.deployment.available', rollup='latest').sum(by=['k8s.cluster.name', 'k8s.namespace.name', 'k8s.deployment.name']).sum().publish(label='A')"

  # optional: time_range = "-15m"
}

resource "signalfx_list_chart" "k8s_top_10_cpu_usage_per_pod" {
  name        = "Top 10 CPU usage per pod (CPU units)"
  description = "Pod name | Node name"

  program_text = <<-EOF
A = data('container_cpu_utilization', rollup='rate').mean(by=['k8s.pod.name', 'k8s.node.name', 'k8s.cluster.name', 'k8s.pod.uid']).scale(0.01).top(count=10).publish(label='A')
B = data('container.cpu.time').mean(by=['k8s.pod.name', 'k8s.node.name', 'k8s.cluster.name', 'k8s.pod.uid']).top(count=10).publish(label='B')
EOF

  sort_by = "-value"
}

resource "signalfx_time_chart" "k8s_network_bytes_per_sec" {
  name        = "Network bytes / sec"
  description = ""

  program_text = "A = data('k8s.pod.network.io', filter=filter('k8s.cluster.name', '*') and filter('k8s.namespace.name', '*') and filter('sf_tags', '*', match_missing=True) and filter('k8s.deployment.name', '*', match_missing=True), rollup='rate', extrapolation='zero').sum(by=['k8s.pod.name', 'k8s.node.name', 'k8s.cluster.name', 'k8s.pod.uid']).publish(label='A')"

  plot_type = "ColumnChart"
}

resource "signalfx_single_value_chart" "k8s_desired_pods_by_deployments" {
  name        = "# Desired pods by deployments"
  description = "Number of pods that should be created by deployments"

  program_text = "A = data('k8s.deployment.desired', rollup='latest').sum(by=['k8s.cluster.name', 'k8s.namespace.name', 'k8s.deployment.name']).sum().publish(label='A')"
}

resource "signalfx_list_chart" "k8s_network_errors_per_sec" {
  name        = "Network errors / sec"
  description = ""

  program_text = "A = data('k8s.pod.network.errors', filter=filter('k8s.cluster.name', '*') and filter('k8s.namespace.name', '*') and filter('k8s.deployment.name', '*', match_missing=True) and filter('sf_tags', '*', match_missing=True), rollup='rate').sum(by=['k8s.pod.name', 'k8s.cluster.name', 'k8s.node.name', 'k8s.pod.uid']).publish(label='A')"

  sort_by = "-value"
}

resource "signalfx_time_chart" "k8s_memory_usage_pct" {
  name        = "Memory usage (%)"
  description = "With EKS/Fargate metric data can possibly go >100%"

  program_text = <<-EOF
A = data('container.memory.usage', filter=filter('k8s.cluster.name', '*') and filter('k8s.namespace.name', '*') and filter('k8s.deployment.name', '*', match_missing=True) and filter('sf_tags', '*', match_missing=True)).sum(by=['k8s.pod.name', 'k8s.node.name', 'k8s.cluster.name', 'k8s.pod.uid']).publish(label='A', enable=False)
B = data('k8s.container.memory_limit', filter=filter('k8s.cluster.name', '*') and filter('k8s.namespace.name', '*') and filter('k8s.deployment.name', '*', match_missing=True) and filter('sf_tags', '*', match_missing=True)).sum(by=['k8s.pod.name', 'k8s.node.name', 'k8s.cluster.name', 'k8s.pod.uid']).above(0, inclusive=True).publish(label='B', enable=False)
C = (A/B*100).publish(label='C')
EOF

  plot_type = "LineChart"
}

resource "signalfx_single_value_chart" "k8s_active_pods" {
  name        = "# Active pods"
  description = "This may include \"pause\" containers used internally by k8s"

  program_text = "A = data('k8s.pod.phase').between(1.5, 2.5, low_inclusive=True, high_inclusive=True).count().publish(label='A')"
}

resource "signalfx_list_chart" "k8s_top_10_pods_by_avg_memory_usage" {
  name        = "Top 10 pods by average memory usage (bytes)"
  description = "Pod name | Node name"

  program_text = "A = data('container.memory.usage', filter=filter('k8s.cluster.name', '*') and filter('k8s.namespace.name', '*') and filter('k8s.deployment.name', '*', match_missing=True) and filter('sf_tags', '*', match_missing=True)).mean(by=['k8s.pod.name', 'k8s.node.name', 'k8s.cluster.name', 'k8s.pod.uid']).top(count=10).publish(label='A')"

  sort_by = "-value"
}

resource "signalfx_list_chart" "k8s_pods_by_phase" {
  name        = "# Pods by phase"
  description = ""

  program_text = <<-EOF
B = data('k8s.pod.phase', rollup='latest').between(1.5, 2.5, low_inclusive=True, high_inclusive=True).count().publish(label='B')
A = data('k8s.pod.phase', rollup='latest').between(0, 1.5, low_inclusive=True, high_inclusive=True).count().publish(label='A')
C = data('k8s.pod.phase', rollup='latest').between(2.5, 3.5, low_inclusive=True, high_inclusive=True).count().publish(label='C')
D = data('k8s.pod.phase', rollup='latest').between(3.5, 4.5, low_inclusive=True, high_inclusive=True).count().publish(label='D')
E = data('k8s.pod.phase', rollup='latest').between(4.5, 5.5, low_inclusive=True, high_inclusive=True).count().publish(label='E')
EOF

  sort_by = "+sf_originatingMetric"
}

resource "signalfx_time_chart" "k8s_memory_usage_bytes" {
  name        = "Memory usage (bytes)"
  description = ""

  program_text = "A = data('container.memory.usage', filter=filter('k8s.node.name', '*')).sum(by=['k8s.cluster.name', 'k8s.namespace.name', 'k8s.pod.uid', 'k8s.pod.name', 'k8s.node.name']).publish(label='A')"

  plot_type = "LineChart"
}


resource "signalfx_dashboard" "runner_k8s" {
  name            = "K8S Runners"
  description     = ""
  dashboard_group = signalfx_dashboard_group.forgecicd.id

  variable {
    property         = "k8s.namespace.name"
    alias            = "ForgeCICD Tenant Name"
    description      = ""
    values           = []
    value_required   = false
    values_suggested = var.dashboard_variables.runner_k8s.tenant_names
  }

  variable {
    property         = "k8s.pod.name"
    alias            = "ForgeCICD Instance Id"
    description      = ""
    values           = []
    value_required   = false
    values_suggested = []
  }

  dynamic "variable" {
    for_each = var.dashboard_variables.runner_k8s.dynamic_variables
    content {
      property         = each.value.property
      alias            = each.value.alias
      description      = each.value.description
      values           = each.value.values
      value_required   = each.value.value_required
      values_suggested = each.value.values_suggested
    }
  }
  chart {
    chart_id = signalfx_single_value_chart.k8s_active_pods.id
    row      = 0
    column   = 0
    width    = 3
    height   = 1
  }

  chart {
    chart_id = signalfx_single_value_chart.k8s_available_pods_by_deployments.id
    row      = 0
    column   = 3
    width    = 3
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.k8s_top_10_pods_by_avg_memory_usage.id
    row      = 0
    column   = 9
    width    = 3
    height   = 2
  }

  chart {
    chart_id = signalfx_single_value_chart.k8s_desired_pods_by_deployments.id
    row      = 0
    column   = 6
    width    = 3
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.k8s_pods_by_phase.id
    row      = 1
    column   = 0
    width    = 3
    height   = 2
  }

  chart {
    chart_id = signalfx_time_chart.k8s_memory_usage_pct.id
    row      = 1
    column   = 3
    width    = 3
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.k8s_memory_usage_bytes.id
    row      = 1
    column   = 6
    width    = 3
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.k8s_network_errors_per_sec.id
    row      = 2
    column   = 3
    width    = 5
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.k8s_network_bytes_per_sec.id
    row      = 2
    column   = 8
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.k8s_top_10_cpu_usage_per_pod.id
    row      = 3
    column   = 0
    width    = 3
    height   = 2
  }
}
