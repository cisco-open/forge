locals {
  aws_account_ids = distinct(flatten([
    for var_def in var.dynamic_variables : var_def.values_suggested
    if var_def.property == "aws_account_id"
  ]))
  aws_regions = distinct(flatten([
    for var_def in var.dynamic_variables : var_def.values_suggested
    if var_def.property == "aws_region"
  ]))
  product_family_names = distinct(flatten([
    for var_def in var.dynamic_variables : var_def.values_suggested
    if var_def.property == "aws_tag_ProductFamilyName"
  ]))

  aws_account_filter = length(local.aws_account_ids) > 0 ? join(" or ", [
    for account_id in sort(local.aws_account_ids) : "filter('aws_account_id', '${account_id}')"
  ]) : "filter('aws_account_id', '__forge_aws_account_scope_not_configured__')"
  aws_region_filter = length(local.aws_regions) > 0 ? join(" or ", [
    for aws_region in sort(local.aws_regions) : "filter('aws_region', '${aws_region}')"
  ]) : "filter('aws_region', '__forge_aws_region_scope_not_configured__')"
  product_family_filter = length(local.product_family_names) > 0 ? join(" or ", [
    for product_family_name in sort(local.product_family_names) : "filter('aws_tag_ProductFamilyName', '${product_family_name}')"
  ]) : "filter('aws_tag_ProductFamilyName', '__forge_product_family_scope_not_configured__')"

  aws_platform_filter     = "(${local.aws_account_filter}) and (${local.aws_region_filter}) and (${local.product_family_filter})"
  control_plane_filter    = "(${local.aws_platform_filter}) and (not filter('aws_tag_TenantName', '*'))"
  lambda_dimension_filter = "filter('namespace', 'AWS/Lambda') and filter('aws_function_name', '*')"
}

resource "signalfx_single_value_chart" "function_count" {
  name        = "# Control-plane functions"
  description = "Number of Forge Lambda functions without the TenantName tag in the selected AWS scope."

  program_text = "A = data('Invocations', filter=(${local.control_plane_filter}) and (${local.lambda_dimension_filter}) and filter('stat', 'sum'), rollup='sum', extrapolation='zero').count(by=['aws_function_name']).count().publish(label='A')"

  color_by = "Dimension"

  viz_options {
    display_name = "Control-plane functions"
    label        = "A"
  }
}

resource "signalfx_single_value_chart" "total_invocations" {
  name        = "Invocations - sum(30m)"
  description = "Total invocations for Forge control-plane Lambda functions over the last 30 minutes."

  program_text = "A = data('Invocations', filter=(${local.control_plane_filter}) and (${local.lambda_dimension_filter}) and filter('stat', 'sum'), rollup='sum', extrapolation='zero').sum(over='30m').sum().publish(label='A')"

  color_by = "Dimension"

  viz_options {
    display_name = "Invocations"
    label        = "A"
  }
}

resource "signalfx_single_value_chart" "total_errors" {
  name        = "Errors - sum(30m)"
  description = "Total errors for Forge control-plane Lambda functions over the last 30 minutes."

  program_text = "A = data('Errors', filter=(${local.control_plane_filter}) and (${local.lambda_dimension_filter}) and filter('stat', 'sum'), rollup='sum', extrapolation='zero').sum(over='30m').sum().publish(label='A')"

  color_by = "Dimension"

  viz_options {
    display_name = "Errors"
    label        = "A"
  }
}

resource "signalfx_single_value_chart" "total_throttles" {
  name        = "Throttles - sum(30m)"
  description = "Total throttles for Forge control-plane Lambda functions over the last 30 minutes."

  program_text = "A = data('Throttles', filter=(${local.control_plane_filter}) and (${local.lambda_dimension_filter}) and filter('stat', 'sum'), rollup='sum', extrapolation='zero').sum(over='30m').sum().publish(label='A')"

  color_by = "Dimension"

  viz_options {
    display_name = "Throttles"
    label        = "A"
  }
}

resource "signalfx_time_chart" "invocations_by_function" {
  name        = "Invocations by control-plane function"
  description = "Five-minute invocation volume by Forge control-plane Lambda function and AWS region."

  program_text = "A = data('Invocations', filter=(${local.control_plane_filter}) and (${local.lambda_dimension_filter}) and filter('stat', 'sum'), rollup='sum', extrapolation='zero').sum(over='5m').sum(by=['aws_region', 'aws_function_name']).publish(label='A')"

  plot_type                 = "LineChart"
  axes_precision            = 0
  disable_sampling          = true
  on_chart_legend_dimension = "aws_function_name"
  time_range                = 3600

  axis_left {
    label     = "Invocations / 5m"
    min_value = 0
  }

  legend_options_fields {
    enabled  = true
    property = "aws_region"
  }

  legend_options_fields {
    enabled  = true
    property = "aws_function_name"
  }

  viz_options {
    display_name = "Invocations"
    label        = "A"
  }
}

resource "signalfx_time_chart" "errors_and_throttles_by_function" {
  name        = "Errors and throttles by control-plane function"
  description = "Five-minute error and throttle counts by Forge control-plane Lambda function and AWS region."

  program_text = <<-EOF
errors = data('Errors', filter=(${local.control_plane_filter}) and (${local.lambda_dimension_filter}) and filter('stat', 'sum'), rollup='sum', extrapolation='zero').sum(over='5m').sum(by=['aws_region', 'aws_function_name']).publish(label='A')
throttles = data('Throttles', filter=(${local.control_plane_filter}) and (${local.lambda_dimension_filter}) and filter('stat', 'sum'), rollup='sum', extrapolation='zero').sum(over='5m').sum(by=['aws_region', 'aws_function_name']).publish(label='B')
EOF

  plot_type                 = "LineChart"
  axes_precision            = 0
  disable_sampling          = true
  on_chart_legend_dimension = "aws_function_name"
  time_range                = 3600

  axis_left {
    label     = "Events / 5m"
    min_value = 0
  }

  legend_options_fields {
    enabled  = true
    property = "aws_region"
  }

  legend_options_fields {
    enabled  = true
    property = "aws_function_name"
  }

  viz_options {
    display_name = "Errors"
    label        = "A"
  }

  viz_options {
    display_name = "Throttles"
    label        = "B"
  }
}

resource "signalfx_time_chart" "duration_by_function" {
  name        = "Average duration by control-plane function"
  description = "Average execution duration by Forge control-plane Lambda function and AWS region."

  program_text = "A = data('Duration', filter=(${local.control_plane_filter}) and (${local.lambda_dimension_filter}) and filter('stat', 'mean'), rollup='average').mean(over='5m').mean(by=['aws_region', 'aws_function_name']).publish(label='A')"

  plot_type                 = "LineChart"
  axes_precision            = 0
  disable_sampling          = true
  on_chart_legend_dimension = "aws_function_name"
  time_range                = 3600

  axis_left {
    label     = "Milliseconds"
    min_value = 0
  }

  legend_options_fields {
    enabled  = true
    property = "aws_region"
  }

  legend_options_fields {
    enabled  = true
    property = "aws_function_name"
  }

  viz_options {
    display_name = "Average duration"
    label        = "A"
    value_unit   = "Millisecond"
  }
}

resource "terraform_data" "dashboard_parent" {
  triggers_replace = var.dashboard_group
}

resource "signalfx_time_chart" "health_alerts" {
  name        = "Lambda control-plane health alerts"
  description = "Central alert timeline for shared Forge Lambda errors and throttles. Lambda metric charts remain alert-free for clear correlation."

  program_text = "alerts(detector_id='${var.detector_id}').publish(label='Lambda control-plane health alerts')"

  plot_type        = "LineChart"
  show_event_lines = true
  time_range       = 3600
}

resource "signalfx_dashboard" "lambda_control_plane" {
  name            = "Forge Control Plane - Lambdas"
  description     = "Health and activity for Forge Lambda functions that are not assigned to a tenant."
  dashboard_group = var.dashboard_group
  time_range      = "-1h"

  lifecycle {
    replace_triggered_by = [
      terraform_data.dashboard_parent,
    ]
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

  chart {
    chart_id = signalfx_single_value_chart.function_count.id
    row      = 0
    column   = 0
    width    = 3
    height   = 1
  }

  chart {
    chart_id = signalfx_single_value_chart.total_invocations.id
    row      = 0
    column   = 3
    width    = 3
    height   = 1
  }

  chart {
    chart_id = signalfx_single_value_chart.total_errors.id
    row      = 0
    column   = 6
    width    = 3
    height   = 1
  }

  chart {
    chart_id = signalfx_single_value_chart.total_throttles.id
    row      = 0
    column   = 9
    width    = 3
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.invocations_by_function.id
    row      = 1
    column   = 0
    width    = 12
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.errors_and_throttles_by_function.id
    row      = 2
    column   = 0
    width    = 12
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.duration_by_function.id
    row      = 3
    column   = 0
    width    = 12
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.health_alerts.id
    row      = 4
    column   = 0
    width    = 12
    height   = 1
  }
}
