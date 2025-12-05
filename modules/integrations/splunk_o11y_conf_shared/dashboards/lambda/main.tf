resource "signalfx_time_chart" "provisioned_concurrent_executions_by_version" {
  name         = "Provisioned concurrent executions by version"
  description  = "The number of events that are being processed on provisioned concurrency. For each invocation of an alias or version with provisioned concurrency, Lambda emits the current count."
  program_text = <<-EOF
A = data('ProvisionedConcurrentExecutions', filter=filter('stat', 'upper') and filter('Resource', '*') and filter('ExecutedVersion', '*')).sum(by=['ExecutedVersion']).publish(label='A')
EOF

  plot_type   = "AreaChart"
  unit_prefix = "Metric"
  color_by    = "Dimension"
  timezone    = "UTC"
  stacked     = true

  axes_precision            = 0
  on_chart_legend_dimension = "ExecutedVersion"

  time_range = 900

  viz_options {
    axis         = "left"
    display_name = "Provisioned concurrent executions"
    label        = "A"
  }

}

resource "signalfx_time_chart" "provisioned_concurrency_invocations_by_version" {
  name         = "Provisioned concurrency invocations by version"
  description  = "The number of invocations that are run on provisioned concurrency. Lambda increments the count once for each invocation that runs on provisioned concurrency."
  program_text = <<-EOF
A = data('ProvisionedConcurrencyInvocations', filter=filter('stat', 'sum') and filter('Resource', '*') and filter('ExecutedVersion', '*'), rollup='rate').sum(by=['ExecutedVersion']).publish(label='A')
EOF

  plot_type   = "AreaChart"
  unit_prefix = "Metric"
  color_by    = "Dimension"
  timezone    = "UTC"
  stacked     = true

  axes_precision            = 0
  on_chart_legend_dimension = "ExecutedVersion"
  time_range                = 900

  legend_options_fields {
    enabled  = false
    property = "AWSUniqueId"
  }
  legend_options_fields {
    enabled  = true
    property = "ExecutedVersion"
  }
  legend_options_fields {
    enabled  = true
    property = "FunctionName"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_originatingMetric"
  }
  legend_options_fields {
    enabled  = false
    property = "namespace"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_metric"
  }
  legend_options_fields {
    enabled  = false
    property = "Resource"
  }
  legend_options_fields {
    enabled  = false
    property = "stat"
  }

  viz_options {
    axis         = "left"
    display_name = "Provisioned concurrent invocations"
    label        = "A"
  }
}

resource "signalfx_time_chart" "provisioned_concurrency_spillover_invocations_by_version" {
  name         = "Provisioned concurrency spillover invocations by version"
  description  = "The number of invocations that are run on nonprovisioned concurrency, when all provisioned concurrency is in use. For a version or alias that is configured to use provisioned concurrency, Lambda increments the count once for each invocation that runs on non-provisioned concurrency."
  program_text = <<-EOF
A = data('ProvisionedConcurrencySpilloverInvocations', filter=filter('stat', 'sum') and filter('Resource', '*') and filter('ExecutedVersion', '*'), rollup='rate').sum(by=['ExecutedVersion']).publish(label='A')
EOF

  plot_type   = "AreaChart"
  unit_prefix = "Metric"
  color_by    = "Dimension"
  timezone    = "UTC"
  stacked     = true

  axes_precision            = 0
  on_chart_legend_dimension = "ExecutedVersion"
  time_range                = 900

  legend_options_fields {
    enabled  = false
    property = "AWSUniqueId"
  }
  legend_options_fields {
    enabled  = true
    property = "ExecutedVersion"
  }
  legend_options_fields {
    enabled  = true
    property = "FunctionName"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_originatingMetric"
  }
  legend_options_fields {
    enabled  = false
    property = "namespace"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_metric"
  }
  legend_options_fields {
    enabled  = false
    property = "Resource"
  }
  legend_options_fields {
    enabled  = false
    property = "stat"
  }

  viz_options {
    axis         = "left"
    display_name = "Provisioned concurrent invocations"
    label        = "A"
  }
}

resource "signalfx_single_value_chart" "total_spillover_invocations" {
  name        = "Total spillover invocations"
  description = "Over 5m | Spillover invocations are run on nonprovisioned concurrency, when all provisioned concurrency is in use."
  unit_prefix = "Metric"
  color_by    = "Dimension"

  program_text = <<-EOF
A = data('ProvisionedConcurrencySpilloverInvocations', filter=filter('stat', 'sum') and filter('Resource', '*') and filter('ExecutedVersion', '*'), rollup='rate').sum(over='5m').sum().publish(label='A')
EOF

  viz_options {
    display_name = "Provisioned concurrent invocations"
    label        = "A"
  }
}

resource "signalfx_list_chart" "percent_invocations_by_version" {
  name                    = "% invocations by version"
  description             = "The % of total invocations handled by version"
  unit_prefix             = "Metric"
  color_by                = "Dimension"
  secondary_visualization = "Sparkline"
  sort_by                 = "-value"

  program_text = <<-EOF
C = (B/A).scale(100).publish(label='C')
A = data('Invocations', filter=filter('namespace', 'AWS/Lambda') and filter('stat', 'sum') and filter('Resource', '*') and filter('ExecutedVersion', '*'), rollup='sum', extrapolation='zero').sum().publish(label='A', enable=False)
B = data('Invocations', filter=filter('namespace', 'AWS/Lambda') and filter('stat', 'sum') and filter('Resource', '*') and filter('ExecutedVersion', '*'), rollup='sum', extrapolation='zero').sum(by=['ExecutedVersion']).publish(label='B', enable=False)
EOF

  time_range = 900

  legend_options_fields {
    enabled  = true
    property = "sf_metric"
  }
  legend_options_fields {
    enabled  = true
    property = "ExecutedVersion"
  }
  legend_options_fields {
    enabled  = false
    property = "AWSUniqueId"
  }
  legend_options_fields {
    enabled  = false
    property = "FunctionName"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_originatingMetric"
  }
  legend_options_fields {
    enabled  = false
    property = "namespace"
  }
  legend_options_fields {
    enabled  = false
    property = "Resource"
  }
  legend_options_fields {
    enabled  = false
    property = "stat"
  }
  legend_options_fields {
    enabled  = false
    property = "aws_function_version"
  }

  viz_options {
    display_name = "A"
    label        = "A"
  }
  viz_options {
    display_name = "B"
    label        = "B"
  }
  viz_options {
    display_name = "Version"
    label        = "C"
    value_suffix = "%"
  }
}

resource "signalfx_time_chart" "errors_by_version" {
  name         = "Errors by version"
  description  = "The number of invocations that failed due to errors in the function (response code 4XX)."
  program_text = <<-EOF
A = data('Errors', filter=filter('namespace', 'AWS/Lambda') and filter('stat', 'sum') and filter('ExecutedVersion', '*') and filter('Resource', '*'), rollup='sum').sum(by=['ExecutedVersion']).publish(label='A')
EOF

  plot_type   = "AreaChart"
  unit_prefix = "Metric"
  color_by    = "Dimension"
  timezone    = "UTC"
  stacked     = false

  axes_precision            = 0
  on_chart_legend_dimension = "ExecutedVersion"

  time_range = 900

  legend_options_fields {
    enabled  = false
    property = "AWSUniqueId"
  }
  legend_options_fields {
    enabled  = true
    property = "FunctionName"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_originatingMetric"
  }
  legend_options_fields {
    enabled  = false
    property = "namespace"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_metric"
  }
  legend_options_fields {
    enabled  = false
    property = "Resource"
  }
  legend_options_fields {
    enabled  = false
    property = "stat"
  }
  legend_options_fields {
    enabled  = false
    property = "aws_function_version"
  }
  legend_options_fields {
    enabled  = true
    property = "ExecutedVersion"
  }

  viz_options {
    axis         = "left"
    display_name = "Errors by version"
    label        = "A"
    value_suffix = "-errors"
  }
}

resource "signalfx_single_value_chart" "total_throttles" {
  name        = "Total throttles"
  description = "Over 5m"
  unit_prefix = "Metric"
  color_by    = "Dimension"

  program_text = <<-EOF
A = data('Throttles', filter=filter('namespace', 'AWS/Lambda') and filter('stat', 'sum') and filter('Resource', '*') and (not filter('ExecutedVersion', '*')), rollup='sum', extrapolation='zero').sum(over='5m').sum().publish(label='A')
EOF

  viz_options {
    color        = "yellow"
    display_name = "Throttles - sum(5m) - sum"
    label        = "A"
  }
}

resource "signalfx_list_chart" "avg_duration_by_version" {
  name                    = "Average duration by version"
  unit_prefix             = "Metric"
  color_by                = "Dimension"
  secondary_visualization = "Sparkline"
  sort_by                 = "-value"

  disable_sampling = true

  program_text = <<-EOF
A = data('Duration', filter=filter('namespace', 'AWS/Lambda') and filter('stat', 'mean') and filter('Resource', '*') and filter('ExecutedVersion', '*'), rollup='average').sum(by=['ExecutedVersion']).publish(label='A')
EOF

  time_range = 900

  legend_options_fields {
    enabled  = false
    property = "AWSUniqueId"
  }
  legend_options_fields {
    enabled  = false
    property = "FunctionName"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_originatingMetric"
  }
  legend_options_fields {
    enabled  = false
    property = "namespace"
  }
  legend_options_fields {
    enabled  = true
    property = "sf_metric"
  }
  legend_options_fields {
    enabled  = false
    property = "Resource"
  }
  legend_options_fields {
    enabled  = false
    property = "stat"
  }
  legend_options_fields {
    enabled  = false
    property = "aws_function_version"
  }
  legend_options_fields {
    enabled  = true
    property = "ExecutedVersion"
  }

  viz_options {
    display_name = "Version"
    label        = "A"
    value_unit   = "Millisecond"
  }
}

resource "signalfx_single_value_chart" "avg_invocation_duration" {
  name        = "Average invocation duration"
  unit_prefix = "Metric"
  color_by    = "Metric"

  program_text = <<-EOF
A = data('Duration', filter=filter('namespace', 'AWS/Lambda') and filter('stat', 'mean') and filter('Resource', '*') and (not filter('ExecutedVersion', '*')), rollup='average').publish(label='A')
EOF

  max_precision = 5

  viz_options {
    display_name = "Duration (ms)"
    label        = "A"
    value_unit   = "Millisecond"
  }
}

resource "signalfx_time_chart" "throttles_by_version" {
  name         = "Throttles by version"
  description  = "The number of Lambda function invocation attempts that were throttled due to invocation rates exceeding the customer’s concurrent limits (error code 429)."
  program_text = <<-EOF
A = data('Throttles', filter=filter('namespace', 'AWS/Lambda') and filter('stat', 'sum') and filter('Resource', '*') and filter('ExecutedVersion', '*'), rollup='sum').sum(by=['ExecutedVersion']).publish(label='A')
EOF

  plot_type   = "AreaChart"
  unit_prefix = "Metric"
  color_by    = "Dimension"
  timezone    = "UTC"
  stacked     = true

  axes_precision            = 0
  on_chart_legend_dimension = "ExecutedVersion"

  time_range = 900

  legend_options_fields {
    enabled  = false
    property = "AWSUniqueId"
  }
  legend_options_fields {
    enabled  = true
    property = "FunctionName"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_originatingMetric"
  }
  legend_options_fields {
    enabled  = false
    property = "namespace"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_metric"
  }
  legend_options_fields {
    enabled  = false
    property = "Resource"
  }
  legend_options_fields {
    enabled  = false
    property = "stat"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_function_version"
  }
  legend_options_fields {
    enabled  = true
    property = "ExecutedVersion"
  }

  viz_options {
    axis         = "left"
    display_name = "Throttles by version"
    label        = "A"
  }

}

resource "signalfx_time_chart" "invocations_by_version" {
  name         = "Invocations by version"
  description  = "The number of times a function is invoked in response to an event or invocation API call."
  program_text = <<-EOF
A = data('Invocations', filter=filter('namespace', 'AWS/Lambda') and filter('stat', 'sum') and filter('Resource', '*') and filter('ExecutedVersion', '*'), rollup='sum').sum(by=['ExecutedVersion']).publish(label='A')
EOF

  plot_type   = "AreaChart"
  unit_prefix = "Metric"
  color_by    = "Dimension"
  timezone    = "UTC"
  stacked     = true


  axes_precision            = 0
  on_chart_legend_dimension = "ExecutedVersion"
  time_range                = 900

  histogram_options {
    color_theme = "gold"
  }

  legend_options_fields {
    enabled  = false
    property = "AWSUniqueId"
  }
  legend_options_fields {
    enabled  = true
    property = "FunctionName"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_originatingMetric"
  }
  legend_options_fields {
    enabled  = false
    property = "namespace"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_metric"
  }
  legend_options_fields {
    enabled  = false
    property = "Resource"
  }
  legend_options_fields {
    enabled  = false
    property = "stat"
  }
  legend_options_fields {
    enabled  = false
    property = "aws_function_version"
  }
  legend_options_fields {
    enabled  = true
    property = "ExecutedVersion"
  }

  viz_options {
    axis         = "left"
    display_name = "Invocations by version"
    label        = "A"
    value_suffix = "-invocations"
  }

}

resource "signalfx_time_chart" "invocations" {
  name         = "Invocations"
  description  = "The number of times a function is invoked in response to an event or invocation API call and associated errors or throttles."
  program_text = <<-EOF
A = data('Invocations', filter=filter('namespace', 'AWS/Lambda') and filter('stat', 'sum') and filter('Resource', '*') and (not filter('ExecutedVersion', '*')), rollup='sum').sum().publish(label='A')
EOF

  plot_type   = "AreaChart"
  unit_prefix = "Metric"
  color_by    = "Dimension"
  timezone    = "UTC"
  stacked     = false

  axes_precision            = 0
  on_chart_legend_dimension = "plot_label"

  time_range = 900

  histogram_options {
    color_theme = "gold"
  }

  legend_options_fields {
    enabled  = false
    property = "AWSUniqueId"
  }
  legend_options_fields {
    enabled  = true
    property = "FunctionName"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_originatingMetric"
  }
  legend_options_fields {
    enabled  = false
    property = "namespace"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_metric"
  }
  legend_options_fields {
    enabled  = false
    property = "Resource"
  }
  legend_options_fields {
    enabled  = false
    property = "stat"
  }
  legend_options_fields {
    enabled  = false
    property = "aws_function_version"
  }
  legend_options_fields {
    enabled  = true
    property = "ExecutedVersion"
  }

  viz_options {
    axis         = "left"
    display_name = "Invocations"
    label        = "A"
  }
}

resource "signalfx_single_value_chart" "total_errors" {
  name        = "Total errors"
  description = "Over 5m"
  unit_prefix = "Metric"
  color_by    = "Dimension"

  program_text = <<-EOF
A = data('Errors', filter=filter('namespace', 'AWS/Lambda') and filter('stat', 'sum') and filter('Resource', '*') and (not filter('ExecutedVersion', '*')), rollup='sum', extrapolation='zero').sum(over='5m').sum().publish(label='A')
EOF

  viz_options {
    color        = "brown"
    display_name = "Errors"
    label        = "A"
  }
}

resource "signalfx_time_chart" "provisioned_concurrency_utilization" {
  name         = "Provisioned concurrency utilization"
  description  = "The number of events that are being processed on provisioned concurrency, divided by the total amount of provisioned concurrency allocated. For example, .5 indicates that 50 percent of allocated provisioned concurrency is in use. For each invocation of an alias or version with provisioned concurrency, Lambda emits the current count."
  program_text = <<-EOF
A = data('ProvisionedConcurrencyUtilization', filter=filter('stat', 'upper') and filter('Resource', '*') and filter('ExecutedVersion', '*')).scale(100).publish(label='A')
EOF

  plot_type   = "LineChart"
  unit_prefix = "Metric"
  color_by    = "Dimension"
  timezone    = "UTC"
  stacked     = false

  axes_include_zero         = true
  axes_precision            = 0
  on_chart_legend_dimension = "ExecutedVersion"

  time_range = 900

  legend_options_fields {
    enabled  = false
    property = "AWSUniqueId"
  }
  legend_options_fields {
    enabled  = true
    property = "FunctionName"
  }
  legend_options_fields {
    enabled  = true
    property = "ExecutedVersion"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_originatingMetric"
  }
  legend_options_fields {
    enabled  = false
    property = "namespace"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_metric"
  }
  legend_options_fields {
    enabled  = false
    property = "Resource"
  }
  legend_options_fields {
    enabled  = false
    property = "stat"
  }

  viz_options {
    axis         = "left"
    display_name = "Provisioned concurrency utilization"
    label        = "A"
    value_suffix = "%"
  }
}

resource "signalfx_single_value_chart" "total_invocations" {
  name        = "Total invocations"
  description = "Over 5m"
  unit_prefix = "Metric"
  color_by    = "Dimension"

  program_text = <<-EOF
A = data('Invocations', filter=filter('namespace', 'AWS/Lambda') and filter('stat', 'sum') and filter('Resource', '*') and (not filter('ExecutedVersion', '*')), rollup='sum').sum(over='5m').sum().publish(label='A')
EOF

  viz_options {
    color        = "chartreuse"
    display_name = "Invocations - sum(5m) - sum"
    label        = "A"
  }
}

resource "signalfx_dashboard" "lambda" {
  name            = "Lambdas"
  description     = "Forge CICD Lambda invocation rate, errors, duration, and concurrency."
  dashboard_group = var.dashboard_group

  variable {
    property               = "aws_tag_TenantName"
    alias                  = "ForgeCICD Tenant Name"
    description            = ""
    values                 = []
    value_required         = false
    values_suggested       = var.tenant_names
    restricted_suggestions = true
  }

  dynamic "variable" {
    for_each = var.dynamic_variables
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

  time_range = "-1h"

  chart {
    chart_id = signalfx_time_chart.invocations.id
    column   = 0
    row      = 1
    width    = 3
    height   = 1
  }

  chart {
    chart_id = signalfx_single_value_chart.total_invocations.id
    column   = 0
    row      = 0
    width    = 3
    height   = 1
  }

  chart {
    chart_id = signalfx_single_value_chart.avg_invocation_duration.id
    column   = 3
    row      = 0
    width    = 3
    height   = 1
  }

  chart {
    chart_id = signalfx_single_value_chart.total_spillover_invocations.id
    column   = 6
    row      = 0
    width    = 2
    height   = 1
  }

  chart {
    chart_id = signalfx_single_value_chart.total_errors.id
    column   = 8
    row      = 0
    width    = 2
    height   = 1
  }

  chart {
    chart_id = signalfx_single_value_chart.total_throttles.id
    column   = 10
    row      = 0
    width    = 2
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.invocations_by_version.id
    column   = 3
    row      = 1
    width    = 3
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.provisioned_concurrency_invocations_by_version.id
    column   = 6
    row      = 1
    width    = 3
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.provisioned_concurrent_executions_by_version.id
    column   = 9
    row      = 1
    width    = 3
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.avg_duration_by_version.id
    column   = 0
    row      = 2
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.errors_by_version.id
    column   = 4
    row      = 2
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.throttles_by_version.id
    column   = 8
    row      = 2
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.percent_invocations_by_version.id
    column   = 0
    row      = 3
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.provisioned_concurrency_spillover_invocations_by_version.id
    column   = 4
    row      = 3
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.provisioned_concurrency_utilization.id
    column   = 8
    row      = 3
    width    = 4
    height   = 1
  }
}
