locals {
  k8s_tenant_namespace_filter = length(var.tenant_names) > 0 ? join(" or ", [
    for namespace in sort(var.tenant_names) : "filter('k8s.namespace.name', '${namespace}')"
  ]) : "filter('k8s.namespace.name', '*')"

  k8s_runner_container_filter = "filter('k8s.container.name', 'runner') and (${local.k8s_tenant_namespace_filter})"
}

resource "signalfx_list_chart" "runner_totals_by_runtime" {
  name        = "Runner totals by runtime"
  description = "Shows active EC2 runner instances and K8S runner pods that reached ready at least once in the last 15 minutes."

  program_text = <<-EOF
A = data('CPUUtilization', filter=filter('namespace', 'AWS/EC2') and filter('stat', 'mean'), extrapolation='last_value', maxExtrapolations=2).max(by=['aws_instance_id']).count().publish(label='EC2 runners')
B = data('k8s.container.ready', filter=(${local.k8s_runner_container_filter}), rollup='max').max(over='15m').sum(by=['k8s.pod.uid']).above(0, inclusive=False).count().publish(label='K8S runner pods')
EOF

  sort_by = "-value"

  hide_missing_values     = true
  max_precision           = 0
  secondary_visualization = "Sparkline"
  time_range              = 900
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
  time_range       = 900
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
  name        = "# EC2 runners per tenant"
  description = "Counts active EC2 runner instances by tenant."

  program_text = "A = data('CPUUtilization', filter=filter('namespace', 'AWS/EC2') and filter('stat', 'mean'), extrapolation='last_value', maxExtrapolations=2).max(by=['aws_instance_id', 'aws_tag_TenantName']).count(by=['aws_tag_TenantName']).publish(label='A')"

  sort_by = "-value"

  hide_missing_values     = true
  max_precision           = 0
  secondary_visualization = "Sparkline"
  time_range              = 900
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
  name        = "# EC2 runners by tenant and instance type"
  description = "Counts active EC2 runner instances by tenant and EC2 instance type."

  program_text = "A = data('CPUUtilization', filter=filter('namespace', 'AWS/EC2') and filter('stat', 'mean'), extrapolation='last_value', maxExtrapolations=2).max(by=['aws_instance_id', 'aws_tag_TenantName', 'aws_instance_type']).count(by=['aws_tag_TenantName', 'aws_instance_type']).publish(label='A')"

  sort_by = "-value"

  hide_missing_values     = true
  max_precision           = 0
  secondary_visualization = "Sparkline"
  time_range              = 900
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

resource "signalfx_list_chart" "ec2_runner_hours_by_tenant" {
  name        = "EC2 runner-hours by tenant (24h)"
  description = "Estimates EC2 runner-hours by tenant from average active runner instances over the last 24 hours."

  program_text = "A = data('CPUUtilization', filter=filter('namespace', 'AWS/EC2') and filter('stat', 'mean'), extrapolation='last_value', maxExtrapolations=2).max(by=['aws_instance_id', 'aws_tag_TenantName']).count(by=['aws_tag_TenantName']).mean(over='24h').scale(24).publish(label='A')"

  sort_by = "-value"

  hide_missing_values     = true
  max_precision           = 2
  secondary_visualization = "Sparkline"
  time_range              = 86400
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
    display_name = "EC2 runner-hours"
    label        = "A"
    value_unit   = "Hour"
  }
}

resource "signalfx_list_chart" "ec2_runner_hours_by_tenant_and_instance_type" {
  name        = "EC2 runner-hours by tenant and instance type (24h)"
  description = "Estimates EC2 runner-hours by tenant and instance type from average active runner instances over the last 24 hours."

  program_text = "A = data('CPUUtilization', filter=filter('namespace', 'AWS/EC2') and filter('stat', 'mean'), extrapolation='last_value', maxExtrapolations=2).max(by=['aws_instance_id', 'aws_tag_TenantName', 'aws_instance_type']).count(by=['aws_tag_TenantName', 'aws_instance_type']).mean(over='24h').scale(24).publish(label='A')"

  sort_by = "-value"

  hide_missing_values     = true
  max_precision           = 2
  secondary_visualization = "Sparkline"
  time_range              = 86400
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
    display_name = "EC2 runner-hours"
    label        = "A"
    value_unit   = "Hour"
  }
}

resource "signalfx_list_chart" "k8s_runners_by_tenant" {
  name        = "# K8S runners per tenant"
  description = "Counts running ARC runner pods by tenant namespace."

  program_text = "A = data('k8s.container.ready', filter=(${local.k8s_runner_container_filter}), rollup='latest').sum(by=['k8s.namespace.name', 'k8s.pod.uid']).above(0, inclusive=False).count(by=['k8s.namespace.name']).publish(label='A')"

  sort_by = "-value"

  hide_missing_values     = true
  max_precision           = 0
  secondary_visualization = "Sparkline"
  time_range              = 900
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
  name        = "K8S runner-hours by tenant (24h)"
  description = "Estimates K8S runner-hours by tenant from average running ARC runner pods over the last 24 hours."

  program_text = "A = data('k8s.container.ready', filter=(${local.k8s_runner_container_filter}), rollup='latest').sum(by=['k8s.namespace.name', 'k8s.pod.uid']).above(0, inclusive=False).count(by=['k8s.namespace.name']).mean(over='24h').scale(24).publish(label='A')"

  sort_by = "-value"

  hide_missing_values     = true
  max_precision           = 2
  secondary_visualization = "Sparkline"
  time_range              = 86400
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
    display_name = "K8S runner-hours"
    label        = "A"
    value_unit   = "Hour"
  }
}

resource "signalfx_dashboard" "forge_impact" {
  name            = "ForgeCICD Impact"
  description     = "Forge adoption, runner inventory, and runner-hour usage."
  dashboard_group = var.dashboard_group

  chart {
    chart_id = signalfx_list_chart.runner_totals_by_runtime.id
    row      = 0
    column   = 0
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.active_ec2_runners_by_tenant.id
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
    chart_id = signalfx_time_chart.active_ec2_runners_by_tenant_and_instance_type.id
    row      = 1
    column   = 0
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.active_ec2_runners_by_tenant_and_instance_type.id
    row      = 1
    column   = 6
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.ec2_runner_hours_by_tenant.id
    row      = 2
    column   = 0
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.k8s_runner_hours_by_tenant.id
    row      = 2
    column   = 6
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.ec2_runner_hours_by_tenant_and_instance_type.id
    row      = 3
    column   = 0
    width    = 12
    height   = 1
  }
}
