resource "signalfx_list_chart" "percent_invocations_by_version" {
  name                    = "% invocations by Forge module"
  description             = "The percentage of total invocations handled by each Forge module reference."
  unit_prefix             = "Metric"
  color_by                = "Dimension"
  secondary_visualization = "Sparkline"
  sort_by                 = "-value"

  program_text = <<-EOF
A = data('Invocations', filter=(${var.lambda_dimension_filter}) and filter('stat', 'sum') and filter('aws_tag_ForgeModuleRef', '*'), rollup='sum', extrapolation='zero').sum(by=['aws_tag_TenantName']).publish(label='A', enable=False)
B = data('Invocations', filter=(${var.lambda_dimension_filter}) and filter('stat', 'sum') and filter('aws_tag_ForgeModuleRef', '*'), rollup='sum', extrapolation='zero').sum(by=['aws_tag_TenantName', 'aws_function_name', 'aws_tag_ForgeModuleRef']).publish(label='B', enable=False)
C = (B/A).scale(100).publish(label='C')
EOF

  time_range = 3600

  legend_options_fields {
    enabled  = false
    property = "sf_metric"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_tag_ForgeModuleRef"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_tag_TenantName"
  }
  legend_options_fields {
    enabled  = false
    property = "AWSUniqueId"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_function_name"
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
  viz_options {
    display_name = "A"
    label        = "A"
  }
  viz_options {
    display_name = "B"
    label        = "B"
  }
  viz_options {
    display_name = "Invocation share by Forge module"
    label        = "C"
    value_suffix = "%"
  }
}

resource "signalfx_time_chart" "errors_by_version" {
  name         = "Errors by Forge module"
  description  = "The number of invocations that failed due to errors in the function (response code 4XX)."
  program_text = <<-EOF
A = data('Errors', filter=(${var.lambda_dimension_filter}) and filter('stat', 'sum') and filter('aws_tag_ForgeModuleRef', '*'), rollup='sum').sum(by=['aws_tag_TenantName', 'aws_function_name', 'aws_tag_ForgeModuleRef']).publish(label='A')
EOF

  plot_type   = "AreaChart"
  unit_prefix = "Metric"
  color_by    = "Dimension"
  timezone    = "UTC"
  stacked     = false

  axes_precision            = 0
  on_chart_legend_dimension = "aws_tag_ForgeModuleRef"

  time_range = 3600

  legend_options_fields {
    enabled  = false
    property = "AWSUniqueId"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_function_name"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_tag_TenantName"
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
    property = "aws_tag_ForgeModuleRef"
  }
  legend_options_fields {
    enabled  = false
    property = "ExecutedVersion"
  }

  viz_options {
    axis         = "left"
    display_name = "Errors"
    label        = "A"
    value_suffix = " errors"
  }
}

resource "signalfx_single_value_chart" "total_throttles" {
  name        = "Total throttles"
  description = "Last hour."
  unit_prefix = "Metric"
  color_by    = "Dimension"

  program_text = <<-EOF
A = data('Throttles', filter=(${var.lambda_dimension_filter}) and filter('stat', 'sum') and filter('aws_tag_TenantName', '*') and filter('aws_tag_ForgeModuleRef', '*'), rollup='sum', extrapolation='zero').sum(over='1h').sum().publish(label='A')
EOF

  viz_options {
    color        = "yellow"
    display_name = "Throttles - sum(1h) - sum"
    label        = "A"
  }
}

resource "signalfx_list_chart" "avg_duration_by_version" {
  name                    = "Average duration by Forge module"
  unit_prefix             = "Metric"
  color_by                = "Dimension"
  secondary_visualization = "Sparkline"
  sort_by                 = "-value"

  disable_sampling = true

  program_text = <<-EOF
A = data('Duration', filter=(${var.lambda_dimension_filter}) and filter('stat', 'mean') and filter('aws_tag_ForgeModuleRef', '*'), rollup='average').mean(by=['aws_tag_TenantName', 'aws_function_name', 'aws_tag_ForgeModuleRef']).publish(label='A')
EOF

  time_range = 3600

  legend_options_fields {
    enabled  = false
    property = "AWSUniqueId"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_function_name"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_tag_TenantName"
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
    enabled  = true
    property = "aws_tag_ForgeModuleRef"
  }
  legend_options_fields {
    enabled  = false
    property = "ExecutedVersion"
  }

  viz_options {
    display_name = "Average duration"
    label        = "A"
    value_unit   = "Millisecond"
  }
}

resource "signalfx_single_value_chart" "avg_invocation_duration" {
  name        = "Average invocation duration"
  description = "Average over selected window."
  unit_prefix = "Metric"
  color_by    = "Metric"

  program_text = <<-EOF
A = data('Duration', filter=(${var.lambda_dimension_filter}) and filter('stat', 'mean'), rollup='average').publish(label='A')
EOF

  max_precision = 5

  viz_options {
    display_name = "Duration (ms)"
    label        = "A"
    value_unit   = "Millisecond"
  }
}

resource "signalfx_time_chart" "throttles_by_version" {
  name         = "Throttles by Forge module"
  description  = "The number of Lambda function invocation attempts that were throttled due to invocation rates exceeding the customer’s concurrent limits (error code 429)."
  program_text = <<-EOF
A = data('Throttles', filter=(${var.lambda_dimension_filter}) and filter('stat', 'sum') and filter('aws_tag_ForgeModuleRef', '*'), rollup='sum').sum(by=['aws_tag_TenantName', 'aws_function_name', 'aws_tag_ForgeModuleRef']).publish(label='A')
EOF

  plot_type   = "AreaChart"
  unit_prefix = "Metric"
  color_by    = "Dimension"
  timezone    = "UTC"
  stacked     = true

  axes_precision            = 0
  on_chart_legend_dimension = "aws_tag_ForgeModuleRef"

  time_range = 3600

  legend_options_fields {
    enabled  = false
    property = "AWSUniqueId"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_function_name"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_tag_TenantName"
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
    property = "aws_tag_ForgeModuleRef"
  }
  legend_options_fields {
    enabled  = false
    property = "ExecutedVersion"
  }

  viz_options {
    axis         = "left"
    display_name = "Throttles"
    label        = "A"
  }

}

resource "signalfx_time_chart" "invocations_by_version" {
  name         = "Invocations by Forge module"
  description  = "The number of times a function is invoked in response to an event or invocation API call."
  program_text = <<-EOF
A = data('Invocations', filter=(${var.lambda_dimension_filter}) and filter('stat', 'sum') and filter('aws_tag_ForgeModuleRef', '*'), rollup='sum').sum(by=['aws_tag_TenantName', 'aws_function_name', 'aws_tag_ForgeModuleRef']).publish(label='A')
EOF

  plot_type   = "AreaChart"
  unit_prefix = "Metric"
  color_by    = "Dimension"
  timezone    = "UTC"
  stacked     = true


  axes_precision            = 0
  on_chart_legend_dimension = "aws_tag_ForgeModuleRef"
  time_range                = 3600

  histogram_options {
    color_theme = "gold"
  }

  legend_options_fields {
    enabled  = false
    property = "AWSUniqueId"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_function_name"
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
    property = "aws_tag_ForgeModuleRef"
  }
  legend_options_fields {
    enabled  = false
    property = "ExecutedVersion"
  }

  viz_options {
    axis         = "left"
    display_name = "Invocations"
    label        = "A"
    value_suffix = " invocations"
  }

}

resource "signalfx_time_chart" "invocations" {
  name         = "Invocations"
  description  = "The number of times a function is invoked in response to an event or invocation API call and associated errors or throttles."
  program_text = <<-EOF
A = data('Invocations', filter=(${var.lambda_dimension_filter}) and filter('stat', 'sum'), rollup='sum').sum().publish(label='A')
EOF

  plot_type   = "AreaChart"
  unit_prefix = "Metric"
  color_by    = "Dimension"
  timezone    = "UTC"
  stacked     = false

  axes_precision            = 0
  on_chart_legend_dimension = "plot_label"

  time_range = 3600

  histogram_options {
    color_theme = "gold"
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
    property = "aws_tag_ForgeModuleRef"
  }
  legend_options_fields {
    enabled  = false
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
  description = "Last hour."
  unit_prefix = "Metric"
  color_by    = "Dimension"

  program_text = <<-EOF
A = data('Errors', filter=(${var.lambda_dimension_filter}) and filter('stat', 'sum') and filter('aws_tag_TenantName', '*') and filter('aws_tag_ForgeModuleRef', '*'), rollup='sum', extrapolation='zero').sum(over='1h').sum().publish(label='A')
EOF

  viz_options {
    color        = "brown"
    display_name = "Errors"
    label        = "A"
  }
}

resource "signalfx_single_value_chart" "total_invocations" {
  name        = "Total invocations"
  description = "Last hour."
  unit_prefix = "Metric"
  color_by    = "Dimension"

  program_text = <<-EOF
A = data('Invocations', filter=(${var.lambda_dimension_filter}) and filter('stat', 'sum') and filter('aws_tag_TenantName', '*') and filter('aws_tag_ForgeModuleRef', '*'), rollup='sum').sum(over='1h').sum().publish(label='A')
EOF

  viz_options {
    color        = "chartreuse"
    display_name = "Invocations - sum(1h) - sum"
    label        = "A"
  }
}

resource "signalfx_list_chart" "top_tenants_by_errors" {
  name                    = "Top 10 tenants by Lambda errors"
  description             = "Last hour. Use the tenant value to filter this dashboard, then inspect the per-Lambda charts below."
  unit_prefix             = "Metric"
  color_by                = "Dimension"
  secondary_visualization = "Sparkline"
  sort_by                 = "-value"

  program_text = <<-EOF
A = data('Errors', filter=(${var.lambda_dimension_filter}) and filter('stat', 'sum') and filter('aws_tag_TenantName', '*') and filter('aws_tag_ForgeModuleRef', '*'), rollup='sum', extrapolation='zero').sum(by=['aws_tag_TenantName']).sum(over='1h').above(0).top(count=10).publish(label='A')
EOF

  time_range = 3600

  legend_options_fields {
    enabled  = true
    property = "aws_tag_TenantName"
  }

  viz_options {
    display_name = "Errors"
    label        = "A"
    value_suffix = " errors"
  }
}

resource "signalfx_list_chart" "top_tenants_by_throttles" {
  name                    = "Top 10 tenants by Lambda throttles"
  description             = "Last hour. Use the tenant value to filter this dashboard, then inspect the per-Lambda charts below."
  unit_prefix             = "Metric"
  color_by                = "Dimension"
  secondary_visualization = "Sparkline"
  sort_by                 = "-value"

  program_text = <<-EOF
A = data('Throttles', filter=(${var.lambda_dimension_filter}) and filter('stat', 'sum') and filter('aws_tag_TenantName', '*') and filter('aws_tag_ForgeModuleRef', '*'), rollup='sum', extrapolation='zero').sum(by=['aws_tag_TenantName']).sum(over='1h').above(0).top(count=10).publish(label='A')
EOF

  time_range = 3600

  legend_options_fields {
    enabled  = true
    property = "aws_tag_TenantName"
  }

  viz_options {
    display_name = "Throttles"
    label        = "A"
    value_suffix = " throttles"
  }
}

resource "signalfx_list_chart" "top_lambdas_by_errors" {
  name                    = "Top 10 Lambdas by errors"
  description             = "Last hour. Select one tenant in the dashboard filter to isolate that tenant's failing functions."
  unit_prefix             = "Metric"
  color_by                = "Dimension"
  secondary_visualization = "Sparkline"
  sort_by                 = "-value"

  program_text = <<-EOF
A = data('Errors', filter=(${var.lambda_dimension_filter}) and filter('stat', 'sum') and filter('aws_tag_TenantName', '*') and filter('aws_tag_ForgeModuleRef', '*'), rollup='sum', extrapolation='zero').sum(by=['aws_tag_TenantName', 'aws_function_name', 'aws_tag_ForgeModuleRef']).sum(over='1h').above(0).top(count=10).publish(label='A')
EOF

  time_range = 3600

  legend_options_fields {
    enabled  = true
    property = "aws_tag_TenantName"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_function_name"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_tag_ForgeModuleRef"
  }

  viz_options {
    display_name = "Errors"
    label        = "A"
    value_suffix = " errors"
  }
}

resource "signalfx_list_chart" "top_lambdas_by_throttles" {
  name                    = "Top 10 Lambdas by throttles"
  description             = "Last hour. Select one tenant in the dashboard filter to isolate that tenant's throttled functions."
  unit_prefix             = "Metric"
  color_by                = "Dimension"
  secondary_visualization = "Sparkline"
  sort_by                 = "-value"

  program_text = <<-EOF
A = data('Throttles', filter=(${var.lambda_dimension_filter}) and filter('stat', 'sum') and filter('aws_tag_TenantName', '*') and filter('aws_tag_ForgeModuleRef', '*'), rollup='sum', extrapolation='zero').sum(by=['aws_tag_TenantName', 'aws_function_name', 'aws_tag_ForgeModuleRef']).sum(over='1h').above(0).top(count=10).publish(label='A')
EOF

  time_range = 3600

  legend_options_fields {
    enabled  = true
    property = "aws_tag_TenantName"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_function_name"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_tag_ForgeModuleRef"
  }

  viz_options {
    display_name = "Throttles"
    label        = "A"
    value_suffix = " throttles"
  }
}

resource "terraform_data" "dashboard_parent" {
  triggers_replace = var.dashboard_group
}

resource "signalfx_dashboard" "lambda" {
  name            = "Forge Tenant - Lambdas"
  description     = "Forge CICD Lambda invocation rate, errors, throttles, duration, tenant impact, and Forge module detail."
  dashboard_group = var.dashboard_group

  lifecycle {
    replace_triggered_by = [
      terraform_data.dashboard_parent,
    ]
  }

  variable {
    property               = "aws_tag_TenantName"
    alias                  = "ForgeCICD Tenant Name"
    description            = ""
    values                 = []
    value_required         = false
    values_suggested       = sort(var.tenant_names)
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
    chart_id = signalfx_list_chart.top_tenants_by_errors.id
    column   = 0
    row      = 1
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.top_tenants_by_throttles.id
    column   = 6
    row      = 1
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.top_lambdas_by_errors.id
    column   = 0
    row      = 2
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.top_lambdas_by_throttles.id
    column   = 6
    row      = 2
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.invocations.id
    column   = 0
    row      = 3
    width    = 6
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
    chart_id = signalfx_single_value_chart.total_errors.id
    column   = 6
    row      = 0
    width    = 3
    height   = 1
  }

  chart {
    chart_id = signalfx_single_value_chart.total_throttles.id
    column   = 9
    row      = 0
    width    = 3
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.invocations_by_version.id
    column   = 6
    row      = 3
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.avg_duration_by_version.id
    column   = 0
    row      = 4
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.errors_by_version.id
    column   = 4
    row      = 4
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.throttles_by_version.id
    column   = 8
    row      = 4
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.percent_invocations_by_version.id
    column   = 0
    row      = 5
    width    = 12
    height   = 1
  }
}
