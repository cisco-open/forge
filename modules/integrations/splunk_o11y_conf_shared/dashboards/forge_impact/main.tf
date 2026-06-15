locals {
  k8s_tenant_namespace_filter = length(var.tenant_names) > 0 ? join(" or ", [
    for namespace in sort(var.tenant_names) : "filter('k8s.namespace.name', '${namespace}')"
  ]) : "filter('k8s.namespace.name', '*')"

  k8s_runner_container_filter  = "filter('k8s.container.name', 'runner') and (${local.k8s_tenant_namespace_filter})"
  k8s_runner_pod_dimensions    = "['k8s.cluster.name', 'k8s.namespace.name', 'k8s.pod.name']"
  k8s_runner_container_runtime = "data('container.memory.usage', filter=(${local.k8s_runner_container_filter}), rollup='latest').mean(by=${local.k8s_runner_pod_dimensions})"
  dashboard_window             = "Args.get('ui.dashboard_window', '15m')"
  runner_usage_window          = "Args.get('ui.dashboard_window', '24h')"
  runner_minutes_scale         = 0.016666666666666666
}

resource "signalfx_list_chart" "runner_totals_by_runtime" {
  name        = "Total runners by runtime over selected window"
  description = "Counts EC2 runner instances and K8S runner pods that reported during the selected dashboard time window."

  program_text = <<-EOF
A = data('CPUUtilization', filter=filter('namespace', 'AWS/EC2') and filter('stat', 'mean'), extrapolation='last_value', maxExtrapolations=2).max(by=['aws_instance_id']).count(over=${local.dashboard_window}).above(0, inclusive=False).count().publish(label='EC2 runners')
B = ${local.k8s_runner_container_runtime}.count(over=${local.dashboard_window}).above(0, inclusive=False).count().publish(label='K8S runner pods')
EOF

  sort_by = "-value"

  hide_missing_values     = true
  max_precision           = 0
  secondary_visualization = "Sparkline"
  unit_prefix             = "Metric"

  legend_options_fields {
    enabled  = false
    property = "sf_metric"
  }

  viz_options {
    display_name = "EC2 runners"
    label        = "EC2 runners"
  }
  viz_options {
    display_name = "K8S runner pods"
    label        = "K8S runner pods"
  }
}

resource "signalfx_list_chart" "runner_minutes_by_runtime" {
  name        = "Runner-minutes by runtime over selected window"
  description = "Estimates total EC2 and K8S runner runtime minutes during the selected dashboard time window. EC2 instances must have aws_tag_TenantName."

  program_text = <<-EOF
A = data('CPUUtilization', filter=filter('namespace', 'AWS/EC2') and filter('stat', 'mean') and filter('aws_tag_TenantName', '*'), extrapolation='last_value', maxExtrapolations=2).max(by=['aws_instance_id']).count().fill(value=0, duration=${local.runner_usage_window}).integrate().sum(over=${local.runner_usage_window}).scale(${local.runner_minutes_scale}).publish(label='EC2 runner-minutes')
B = ${local.k8s_runner_container_runtime}.count().fill(value=0, duration=${local.runner_usage_window}).integrate().sum(over=${local.runner_usage_window}).scale(${local.runner_minutes_scale}).publish(label='K8S runner-minutes')
EOF

  sort_by = "-value"

  hide_missing_values     = true
  max_precision           = 2
  secondary_visualization = "Sparkline"
  unit_prefix             = "Metric"

  legend_options_fields {
    enabled  = false
    property = "sf_metric"
  }

  viz_options {
    display_name = "EC2 runner-minutes"
    label        = "EC2 runner-minutes"
  }
  viz_options {
    display_name = "K8S runner-minutes"
    label        = "K8S runner-minutes"
  }
}

resource "signalfx_time_chart" "active_ec2_runners_by_tenant_and_instance_type" {
  name        = "Active EC2 runners by tenant and instance type"
  description = "Tracks active EC2 runner instance count over time by tenant and instance type."

  program_text = <<-EOF
A = data('CPUUtilization', filter=filter('namespace', 'AWS/EC2') and filter('stat', 'mean'), extrapolation='last_value', maxExtrapolations=2).max(by=['aws_instance_id', 'aws_tag_TenantName', 'aws_instance_type']).count(by=['aws_tag_TenantName', 'aws_instance_type']).publish(label='A')
EOF

  plot_type        = "LineChart"
  axes_precision   = 0
  disable_sampling = false
  show_event_lines = false
  unit_prefix      = "Metric"

  axis_left {
    label = "Runners"
  }

  legend_options_fields {
    enabled  = true
    property = "aws_tag_TenantName"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_instance_type"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_metric"
  }

  viz_options {
    display_name = "EC2 runners"
    label        = "A"
  }
}

resource "signalfx_list_chart" "active_ec2_runners_by_tenant" {
  name        = "Active EC2 runners by tenant"
  description = "Counts currently active EC2 runner instances by tenant."

  program_text = "A = data('CPUUtilization', filter=filter('namespace', 'AWS/EC2') and filter('stat', 'mean'), extrapolation='last_value', maxExtrapolations=2).max(by=['aws_instance_id', 'aws_tag_TenantName']).count(by=['aws_tag_TenantName']).publish(label='A')"

  sort_by = "-value"

  hide_missing_values     = true
  max_precision           = 0
  secondary_visualization = "Sparkline"
  unit_prefix             = "Metric"

  legend_options_fields {
    enabled  = true
    property = "aws_tag_TenantName"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_metric"
  }

  viz_options {
    display_name = "EC2 runners"
    label        = "A"
  }
}

resource "signalfx_list_chart" "active_ec2_runners_by_tenant_and_instance_type" {
  name        = "Active EC2 runners by tenant and instance type"
  description = "Counts currently active EC2 runner instances by tenant and EC2 instance type."

  program_text = "A = data('CPUUtilization', filter=filter('namespace', 'AWS/EC2') and filter('stat', 'mean'), extrapolation='last_value', maxExtrapolations=2).max(by=['aws_instance_id', 'aws_tag_TenantName', 'aws_instance_type']).count(by=['aws_tag_TenantName', 'aws_instance_type']).publish(label='A')"

  sort_by = "-value"

  hide_missing_values     = true
  max_precision           = 0
  secondary_visualization = "Sparkline"
  unit_prefix             = "Metric"

  legend_options_fields {
    enabled  = true
    property = "aws_tag_TenantName"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_instance_type"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_metric"
  }

  viz_options {
    display_name = "EC2 runners"
    label        = "A"
  }
}

resource "signalfx_list_chart" "total_ec2_runners_by_tenant" {
  name        = "Total EC2 runners by tenant over selected window"
  description = "Counts EC2 runner instances that reported during the selected dashboard time window by tenant."

  program_text = "A = data('CPUUtilization', filter=filter('namespace', 'AWS/EC2') and filter('stat', 'mean'), extrapolation='last_value', maxExtrapolations=2).max(by=['aws_instance_id', 'aws_tag_TenantName']).count(over=${local.dashboard_window}).above(0, inclusive=False).count(by=['aws_tag_TenantName']).publish(label='A')"

  sort_by = "-value"

  hide_missing_values     = true
  max_precision           = 0
  secondary_visualization = "Sparkline"
  unit_prefix             = "Metric"

  legend_options_fields {
    enabled  = true
    property = "aws_tag_TenantName"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_metric"
  }

  viz_options {
    display_name = "EC2 runners"
    label        = "A"
  }
}

resource "signalfx_list_chart" "ec2_runner_hours_by_tenant" {
  name        = "EC2 runner-minutes by tenant"
  description = "Estimates EC2 runner running minutes by tenant over the selected dashboard time window."

  program_text = "A = data('CPUUtilization', filter=filter('namespace', 'AWS/EC2') and filter('stat', 'mean'), extrapolation='last_value', maxExtrapolations=2).max(by=['aws_instance_id', 'aws_tag_TenantName']).count(by=['aws_tag_TenantName']).fill(value=0, duration=${local.runner_usage_window}).integrate().sum(over=${local.runner_usage_window}).scale(${local.runner_minutes_scale}).publish(label='A')"

  sort_by = "-value"

  hide_missing_values     = true
  max_precision           = 2
  secondary_visualization = "Sparkline"
  unit_prefix             = "Metric"

  legend_options_fields {
    enabled  = true
    property = "aws_tag_TenantName"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_metric"
  }

  viz_options {
    display_name = "EC2 runner-minutes"
    label        = "A"
  }
}

resource "signalfx_list_chart" "ec2_runner_hours_by_tenant_and_instance_type" {
  name        = "EC2 runner-minutes by tenant and instance type"
  description = "Estimates EC2 runner running minutes by tenant and instance type over the selected dashboard time window."

  program_text = "A = data('CPUUtilization', filter=filter('namespace', 'AWS/EC2') and filter('stat', 'mean'), extrapolation='last_value', maxExtrapolations=2).max(by=['aws_instance_id', 'aws_tag_TenantName', 'aws_instance_type']).count(by=['aws_tag_TenantName', 'aws_instance_type']).fill(value=0, duration=${local.runner_usage_window}).integrate().sum(over=${local.runner_usage_window}).scale(${local.runner_minutes_scale}).publish(label='A')"

  sort_by = "-value"

  hide_missing_values     = true
  max_precision           = 2
  secondary_visualization = "Sparkline"
  unit_prefix             = "Metric"

  legend_options_fields {
    enabled  = true
    property = "aws_tag_TenantName"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_instance_type"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_metric"
  }

  viz_options {
    display_name = "EC2 runner-minutes"
    label        = "A"
  }
}

resource "signalfx_list_chart" "k8s_runners_by_tenant" {
  name        = "Active K8S runners by tenant"
  description = "Counts currently reporting ARC runner containers by tenant namespace."

  program_text = "A = ${local.k8s_runner_container_runtime}.count(by=['k8s.namespace.name']).publish(label='A')"

  sort_by = "-value"

  hide_missing_values     = true
  max_precision           = 0
  secondary_visualization = "Sparkline"
  unit_prefix             = "Metric"

  legend_options_fields {
    enabled  = true
    property = "k8s.namespace.name"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_metric"
  }

  viz_options {
    display_name = "K8S runners"
    label        = "A"
  }
}

resource "signalfx_list_chart" "total_k8s_runners_by_tenant" {
  name        = "Total K8S runners by tenant over selected window"
  description = "Counts ARC runner pods that reported during the selected dashboard time window by tenant namespace."

  program_text = "A = ${local.k8s_runner_container_runtime}.count(over=${local.dashboard_window}).above(0, inclusive=False).count(by=['k8s.namespace.name']).publish(label='A')"

  sort_by = "-value"

  hide_missing_values     = true
  max_precision           = 0
  secondary_visualization = "Sparkline"
  unit_prefix             = "Metric"

  legend_options_fields {
    enabled  = true
    property = "k8s.namespace.name"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_metric"
  }

  viz_options {
    display_name = "K8S runners"
    label        = "A"
  }
}

resource "signalfx_list_chart" "k8s_runner_hours_by_tenant" {
  name        = "K8S runner-minutes by tenant"
  description = "Estimates total K8S runner running minutes by tenant over the selected dashboard time window, based on runner container runtime metrics."

  program_text = "A = ${local.k8s_runner_container_runtime}.count(by=['k8s.namespace.name']).fill(value=0, duration=${local.runner_usage_window}).integrate().sum(over=${local.runner_usage_window}).scale(${local.runner_minutes_scale}).publish(label='A')"

  sort_by = "-value"

  hide_missing_values     = true
  max_precision           = 2
  secondary_visualization = "Sparkline"
  unit_prefix             = "Metric"

  legend_options_fields {
    enabled  = true
    property = "k8s.namespace.name"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_metric"
  }

  viz_options {
    display_name = "K8S runner-minutes"
    label        = "A"
  }
}

resource "terraform_data" "dashboard_parent" {
  triggers_replace = var.dashboard_group
}

resource "signalfx_dashboard" "forge_impact" {
  name            = "ForgeCICD Impact"
  description     = "Forge adoption, runner inventory, and runner-minute usage."
  dashboard_group = var.dashboard_group

  # Splunk O11y rejects moving an existing dashboard to a new parent group.
  lifecycle {
    replace_triggered_by = [
      terraform_data.dashboard_parent,
    ]
  }

  chart {
    chart_id = signalfx_list_chart.active_ec2_runners_by_tenant.id
    row      = 0
    column   = 0
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.active_ec2_runners_by_tenant_and_instance_type.id
    row      = 0
    column   = 4
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.k8s_runners_by_tenant.id
    row      = 0
    column   = 8
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.runner_totals_by_runtime.id
    row      = 1
    column   = 0
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.total_ec2_runners_by_tenant.id
    row      = 1
    column   = 4
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.total_k8s_runners_by_tenant.id
    row      = 1
    column   = 8
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.runner_minutes_by_runtime.id
    row      = 2
    column   = 0
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.ec2_runner_hours_by_tenant.id
    row      = 2
    column   = 4
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.k8s_runner_hours_by_tenant.id
    row      = 2
    column   = 8
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.active_ec2_runners_by_tenant_and_instance_type.id
    row      = 3
    column   = 0
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.ec2_runner_hours_by_tenant_and_instance_type.id
    row      = 3
    column   = 6
    width    = 6
    height   = 1
  }
}
