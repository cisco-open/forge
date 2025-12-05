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

}

resource "signalfx_single_value_chart" "total_spillover_invocations" {
  name        = "Total spillover invocations"
  description = "Over 5m | Spillover invocations are run on nonprovisioned concurrency, when all provisioned concurrency is in use."
  unit_prefix = "Metric"
  color_by    = "Dimension"

  program_text = <<-EOF
A = data('ProvisionedConcurrencySpilloverInvocations', filter=filter('stat', 'sum') and filter('Resource', '*') and filter('ExecutedVersion', '*'), rollup='rate').sum(over='5m').sum().publish(label='A')
EOF
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

}

resource "signalfx_single_value_chart" "total_throttles" {
  name        = "Total throttles"
  description = "Over 5m"
  unit_prefix = "Metric"
  color_by    = "Dimension"

  program_text = <<-EOF
A = data('Throttles', filter=filter('namespace', 'AWS/Lambda') and filter('stat', 'sum') and filter('Resource', '*') and (not filter('ExecutedVersion', '*')), rollup='sum', extrapolation='zero').sum(over='5m').sum().publish(label='A')
EOF
}

resource "signalfx_list_chart" "avg_duration_by_version" {
  name                    = "Average duration by version"
  unit_prefix             = "Metric"
  color_by                = "Dimension"
  secondary_visualization = "Sparkline"
  sort_by                 = "-value"

  program_text = <<-EOF
A = data('Duration', filter=filter('namespace', 'AWS/Lambda') and filter('stat', 'mean') and filter('Resource', '*') and filter('ExecutedVersion', '*'), rollup='average').sum(by=['ExecutedVersion']).publish(label='A')
EOF
}

resource "signalfx_single_value_chart" "avg_invocation_duration" {
  name        = "Average invocation duration"
  unit_prefix = "Metric"
  color_by    = "Metric"

  program_text = <<-EOF
A = data('Duration', filter=filter('namespace', 'AWS/Lambda') and filter('stat', 'mean') and filter('Resource', '*') and (not filter('ExecutedVersion', '*')), rollup='average').publish(label='A')
EOF
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

}

resource "signalfx_single_value_chart" "total_errors" {
  name        = "Total errors"
  description = "Over 5m"
  unit_prefix = "Metric"
  color_by    = "Dimension"

  program_text = <<-EOF
A = data('Errors', filter=filter('namespace', 'AWS/Lambda') and filter('stat', 'sum') and filter('Resource', '*') and (not filter('ExecutedVersion', '*')), rollup='sum', extrapolation='zero').sum(over='5m').sum().publish(label='A')
EOF
}

resource "signalfx_time_chart" "provisioned_concurrency_utilization" {
  name         = "Provisioned concurrency utilization"
  description  = "The number of events that are being processed on provisioned concurrency, divided by the total amount of provisioned concurrency allocated."
  program_text = <<-EOF
A = data('ProvisionedConcurrencyUtilization', filter=filter('stat', 'upper') and filter('Resource', '*') and filter('ExecutedVersion', '*')).scale(100).publish(label='A')
EOF

  plot_type   = "LineChart"
  unit_prefix = "Metric"
  color_by    = "Dimension"
  timezone    = "UTC"
  stacked     = false

}

resource "signalfx_single_value_chart" "total_invocations" {
  name        = "Total invocations"
  description = "Over 5m"
  unit_prefix = "Metric"
  color_by    = "Dimension"

  program_text = <<-EOF
A = data('Invocations', filter=filter('namespace', 'AWS/Lambda') and filter('stat', 'sum') and filter('Resource', '*') and (not filter('ExecutedVersion', '*')), rollup='sum').sum(over='5m').sum().publish(label='A')
EOF
}

resource "signalfx_dashboard" "lambda" {
  name            = "Lambdas"
  description     = ""
  dashboard_group = signalfx_dashboard_group.forgecicd.id

  variable {
    property               = "aws_tag_TenantName"
    alias                  = "ForgeCICD Tenant Name"
    description            = ""
    values                 = []
    value_required         = false
    values_suggested       = var.dashboard_variables.lambda.tenant_names
    restricted_suggestions = true
  }

  dynamic "variable" {
    for_each = var.dashboard_variables.lambda.dynamic_variables
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
