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

  aws_platform_filter = "(${local.aws_account_filter}) and (${local.aws_region_filter}) and (${local.product_family_filter})"
  build_queue_filter  = "filter('QueueName', '*-queued-builds') and (not filter('QueueName', '*_dead_letter'))"
}

resource "signalfx_time_chart" "lambda_throttle_attempt_rate" {
  name        = "Forge AWS Lambda throttle attempt rate"
  description = "Regional throttled-attempt percentage for Forge production Lambda functions. Warning baselines: use1 0.5%, usw2 20%, euw1 65% sustained for 10m."

  program_text = <<-EOF
throttles = data('Throttles', filter=(${local.aws_platform_filter}) and (${var.lambda_dimension_filter}) and filter('stat', 'sum'), rollup='sum', extrapolation='zero').sum(over='5m').sum(by=['aws_region'])
invocations = data('Invocations', filter=(${local.aws_platform_filter}) and (${var.lambda_dimension_filter}) and filter('stat', 'sum'), rollup='sum', extrapolation='zero').sum(over='5m').sum(by=['aws_region'])
throttle_attempt_rate = (throttles / (throttles + invocations)).scale(100).publish(label='A')
EOF

  plot_type                 = "LineChart"
  axes_precision            = 2
  disable_sampling          = true
  on_chart_legend_dimension = "aws_region"
  time_range                = 3600

  axis_left {
    label     = "Percent"
    min_value = 0
  }

  legend_options_fields {
    enabled  = true
    property = "aws_region"
  }

  viz_options {
    display_name = "Throttle attempt rate"
    label        = "A"
    value_suffix = "%"
  }
}

resource "signalfx_time_chart" "lambda_throttle_count" {
  name        = "Forge AWS Lambda throttle count"
  description = "Five-minute Forge Lambda throttle count by AWS region. Use with the regional throttle-attempt rate and customer-impact signals; do not page on count alone."

  program_text = "A = data('Throttles', filter=(${local.aws_platform_filter}) and (${var.lambda_dimension_filter}) and filter('stat', 'sum'), rollup='sum', extrapolation='zero').sum(over='5m').sum(by=['aws_region']).publish(label='A')"

  plot_type                 = "LineChart"
  axes_precision            = 0
  disable_sampling          = true
  on_chart_legend_dimension = "aws_region"
  time_range                = 3600

  axis_left {
    label     = "Throttles / 5m"
    min_value = 0
  }

  legend_options_fields {
    enabled  = true
    property = "aws_region"
  }

  viz_options {
    display_name = "Lambda throttles"
    label        = "A"
  }
}

resource "signalfx_time_chart" "build_queue_oldest_age" {
  name        = "Forge AWS build queue oldest age"
  description = "Maximum oldest queued-build message age by AWS region. Warning above 75s for 10m; Major above 300s for 10m; recover below 60s for 15m."

  program_text = <<-EOF
A = data('ApproximateAgeOfOldestMessage', filter=(${local.aws_platform_filter}) and filter('namespace', 'AWS/SQS') and filter('stat', 'upper') and (${local.build_queue_filter})).max(over='5m').max(by=['aws_region']).publish(label='A')
EOF

  plot_type                 = "LineChart"
  axes_precision            = 0
  disable_sampling          = true
  on_chart_legend_dimension = "aws_region"
  time_range                = 3600

  axis_left {
    label     = "Seconds"
    min_value = 0
  }

  legend_options_fields {
    enabled  = true
    property = "aws_region"
  }

  viz_options {
    display_name = "Oldest queued build"
    label        = "A"
    value_unit   = "Second"
  }
}

resource "signalfx_time_chart" "build_queue_visible_backlog" {
  name        = "Forge AWS build queue visible backlog"
  description = "Visible queued-build messages by AWS region. Warning when above 10 for 10m together with oldest-message age above 75s."

  program_text = <<-EOF
A = data('ApproximateNumberOfMessagesVisible', filter=(${local.aws_platform_filter}) and filter('namespace', 'AWS/SQS') and filter('stat', 'upper') and (${local.build_queue_filter})).max(over='5m').sum(by=['aws_region']).publish(label='A')
EOF

  plot_type                 = "LineChart"
  axes_precision            = 0
  disable_sampling          = true
  on_chart_legend_dimension = "aws_region"
  time_range                = 3600

  axis_left {
    label     = "Messages"
    min_value = 0
  }

  legend_options_fields {
    enabled  = true
    property = "aws_region"
  }

  viz_options {
    display_name = "Visible queued builds"
    label        = "A"
  }
}

resource "signalfx_time_chart" "build_queue_dlq_sends" {
  name        = "Forge AWS queued-build DLQ sends"
  description = "Queued-build dead-letter queue sends by AWS region. Any non-zero value in 5m is a Major condition; escalate only with customer impact."

  program_text = <<-EOF
A = data('NumberOfMessagesSent', filter=(${local.aws_platform_filter}) and filter('namespace', 'AWS/SQS') and filter('stat', 'sum') and filter('QueueName', '*_dead_letter'), rollup='sum').sum(over='5m').sum(by=['aws_region']).publish(label='A')
EOF

  plot_type                 = "ColumnChart"
  axes_precision            = 0
  disable_sampling          = true
  on_chart_legend_dimension = "aws_region"
  time_range                = 3600

  axis_left {
    label     = "Messages / 5m"
    min_value = 0
  }

  legend_options_fields {
    enabled  = true
    property = "aws_region"
  }

  viz_options {
    display_name = "Queued-build DLQ sends"
    label        = "A"
  }
}

resource "terraform_data" "dashboard_parent" {
  triggers_replace = var.dashboard_group
}

resource "signalfx_time_chart" "queue_health_alerts" {
  name        = "Regional queue health alerts"
  description = "Central alert timeline for regional queued-build backlog, oldest-message age, and dead-letter queue activity. Metric charts remain alert-free for clear correlation."

  program_text = "alerts(detector_id='${var.detector_id}').publish(label='Regional queue health alerts')"

  plot_type        = "LineChart"
  show_event_lines = true
  time_range       = 3600
}

resource "signalfx_dashboard" "aws_regional_health" {
  name            = "Forge AWS Regional Platform Health"
  description     = "Regional Forge control-plane Lambda throttling and queued-build SQS health."
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
    chart_id = signalfx_time_chart.queue_health_alerts.id
    row      = 0
    column   = 0
    width    = 12
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.lambda_throttle_attempt_rate.id
    row      = 1
    column   = 0
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.lambda_throttle_count.id
    row      = 1
    column   = 6
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.build_queue_oldest_age.id
    row      = 2
    column   = 0
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.build_queue_visible_backlog.id
    row      = 2
    column   = 6
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.build_queue_dlq_sends.id
    row      = 3
    column   = 0
    width    = 12
    height   = 1
  }
}
