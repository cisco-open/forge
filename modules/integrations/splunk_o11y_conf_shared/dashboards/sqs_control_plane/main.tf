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

  aws_platform_filter  = "(${local.aws_account_filter}) and (${local.aws_region_filter}) and (${local.product_family_filter})"
  control_plane_filter = "(${local.aws_platform_filter}) and (not filter('aws_tag_TenantName', '*'))"
  sqs_dimension_filter = "filter('namespace', 'AWS/SQS') and filter('QueueName', '*')"
  dlq_filter           = "filter('QueueName', '*dead-letter*', '*dead_letter*', '*dlq*', '*DLQ*')"
}

resource "signalfx_single_value_chart" "queue_count" {
  name        = "# Control-plane queues"
  description = "Number of Forge SQS queues without the TenantName tag in the selected AWS scope."

  program_text = "A = data('ApproximateNumberOfMessagesVisible', filter=(${local.control_plane_filter}) and (${local.sqs_dimension_filter}) and filter('stat', 'upper'), rollup='latest').count(by=['QueueName']).count().publish(label='A')"

  color_by = "Dimension"

  viz_options {
    display_name = "Control-plane queues"
    label        = "A"
  }
}

resource "signalfx_time_chart" "visible_messages" {
  name        = "Visible messages by control-plane queue"
  description = "Visible backlog by Forge control-plane SQS queue and AWS region."

  program_text = "A = data('ApproximateNumberOfMessagesVisible', filter=(${local.control_plane_filter}) and (${local.sqs_dimension_filter}) and filter('stat', 'upper'), rollup='latest').max(over='5m').sum(by=['aws_region', 'QueueName']).publish(label='A')"

  plot_type                 = "LineChart"
  axes_precision            = 0
  disable_sampling          = true
  on_chart_legend_dimension = "QueueName"
  time_range                = 3600

  axis_left {
    label     = "Messages"
    min_value = 0
  }

  legend_options_fields {
    enabled  = true
    property = "aws_region"
  }

  legend_options_fields {
    enabled  = true
    property = "QueueName"
  }

  viz_options {
    display_name = "Visible messages"
    label        = "A"
  }
}

resource "signalfx_time_chart" "oldest_message_age" {
  name        = "Oldest message age by control-plane queue"
  description = "Oldest visible message age by Forge control-plane SQS queue and AWS region."

  program_text = "A = data('ApproximateAgeOfOldestMessage', filter=(${local.control_plane_filter}) and (${local.sqs_dimension_filter}) and filter('stat', 'upper'), rollup='latest').max(over='5m').max(by=['aws_region', 'QueueName']).publish(label='A')"

  plot_type                 = "LineChart"
  axes_precision            = 0
  disable_sampling          = true
  on_chart_legend_dimension = "QueueName"
  time_range                = 3600

  axis_left {
    label     = "Seconds"
    min_value = 0
  }

  legend_options_fields {
    enabled  = true
    property = "aws_region"
  }

  legend_options_fields {
    enabled  = true
    property = "QueueName"
  }

  viz_options {
    display_name = "Oldest message"
    label        = "A"
    value_unit   = "Second"
  }
}

resource "signalfx_time_chart" "messages_by_operation" {
  name        = "Message operations by control-plane queue"
  description = "Messages sent, received, and deleted by Forge control-plane SQS queue and AWS region."

  program_text = <<-EOF
sent = data('NumberOfMessagesSent', filter=(${local.control_plane_filter}) and (${local.sqs_dimension_filter}) and filter('stat', 'sum'), rollup='sum', extrapolation='zero').sum(over='5m').sum(by=['aws_region', 'QueueName']).publish(label='A')
received = data('NumberOfMessagesReceived', filter=(${local.control_plane_filter}) and (${local.sqs_dimension_filter}) and filter('stat', 'sum'), rollup='sum', extrapolation='zero').sum(over='5m').sum(by=['aws_region', 'QueueName']).publish(label='B')
deleted = data('NumberOfMessagesDeleted', filter=(${local.control_plane_filter}) and (${local.sqs_dimension_filter}) and filter('stat', 'sum'), rollup='sum', extrapolation='zero').sum(over='5m').sum(by=['aws_region', 'QueueName']).publish(label='C')
EOF

  plot_type                 = "LineChart"
  axes_precision            = 0
  disable_sampling          = true
  on_chart_legend_dimension = "QueueName"
  time_range                = 3600

  axis_left {
    label     = "Messages / 5m"
    min_value = 0
  }

  legend_options_fields {
    enabled  = true
    property = "aws_region"
  }

  legend_options_fields {
    enabled  = true
    property = "QueueName"
  }

  viz_options {
    display_name = "Sent"
    label        = "A"
  }

  viz_options {
    display_name = "Received"
    label        = "B"
  }

  viz_options {
    display_name = "Deleted"
    label        = "C"
  }
}

resource "signalfx_time_chart" "messages_by_state" {
  name        = "Messages by control-plane queue state"
  description = "Visible, delayed, and in-flight messages by Forge control-plane SQS queue and AWS region."

  program_text = <<-EOF
visible = data('ApproximateNumberOfMessagesVisible', filter=(${local.control_plane_filter}) and (${local.sqs_dimension_filter}) and filter('stat', 'upper'), rollup='latest').max(over='5m').sum(by=['aws_region', 'QueueName']).publish(label='A')
delayed = data('ApproximateNumberOfMessagesDelayed', filter=(${local.control_plane_filter}) and (${local.sqs_dimension_filter}) and filter('stat', 'upper'), rollup='latest').max(over='5m').sum(by=['aws_region', 'QueueName']).publish(label='B')
in_flight = data('ApproximateNumberOfMessagesNotVisible', filter=(${local.control_plane_filter}) and (${local.sqs_dimension_filter}) and filter('stat', 'upper'), rollup='latest').max(over='5m').sum(by=['aws_region', 'QueueName']).publish(label='C')
EOF

  plot_type                 = "LineChart"
  axes_precision            = 0
  disable_sampling          = true
  on_chart_legend_dimension = "QueueName"
  time_range                = 3600

  axis_left {
    label     = "Messages"
    min_value = 0
  }

  legend_options_fields {
    enabled  = true
    property = "aws_region"
  }

  legend_options_fields {
    enabled  = true
    property = "QueueName"
  }

  viz_options {
    display_name = "Visible"
    label        = "A"
  }

  viz_options {
    display_name = "Delayed"
    label        = "B"
  }

  viz_options {
    display_name = "In flight"
    label        = "C"
  }
}

resource "signalfx_time_chart" "dlq_visible_messages" {
  name        = "Control-plane DLQ visible messages"
  description = "Visible messages in Forge control-plane dead-letter queues."

  program_text = "A = data('ApproximateNumberOfMessagesVisible', filter=(${local.control_plane_filter}) and filter('namespace', 'AWS/SQS') and (${local.dlq_filter}) and filter('stat', 'upper'), rollup='latest').max(over='5m').sum(by=['aws_region', 'QueueName']).publish(label='A')"

  plot_type                 = "ColumnChart"
  axes_precision            = 0
  disable_sampling          = true
  on_chart_legend_dimension = "QueueName"
  time_range                = 3600

  axis_left {
    label     = "Messages"
    min_value = 0
  }

  legend_options_fields {
    enabled  = true
    property = "aws_region"
  }

  legend_options_fields {
    enabled  = true
    property = "QueueName"
  }

  viz_options {
    display_name = "DLQ messages"
    label        = "A"
  }
}

resource "signalfx_time_chart" "dlq_oldest_message_age" {
  name        = "Control-plane DLQ oldest message age"
  description = "Oldest visible message age in Forge control-plane dead-letter queues."

  program_text = "A = data('ApproximateAgeOfOldestMessage', filter=(${local.control_plane_filter}) and filter('namespace', 'AWS/SQS') and (${local.dlq_filter}) and filter('stat', 'upper'), rollup='latest').max(over='5m').max(by=['aws_region', 'QueueName']).publish(label='A')"

  plot_type                 = "LineChart"
  axes_precision            = 0
  disable_sampling          = true
  on_chart_legend_dimension = "QueueName"
  time_range                = 3600

  axis_left {
    label     = "Seconds"
    min_value = 0
  }

  legend_options_fields {
    enabled  = true
    property = "aws_region"
  }

  legend_options_fields {
    enabled  = true
    property = "QueueName"
  }

  viz_options {
    display_name = "Oldest DLQ message"
    label        = "A"
    value_unit   = "Second"
  }
}

resource "terraform_data" "dashboard_parent" {
  triggers_replace = var.dashboard_group
}

resource "signalfx_dashboard" "sqs_control_plane" {
  name            = "Forge Control Plane - SQS"
  description     = "Health and activity for Forge SQS queues that are not assigned to a tenant."
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
    chart_id = signalfx_single_value_chart.queue_count.id
    row      = 0
    column   = 0
    width    = 12
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.visible_messages.id
    row      = 1
    column   = 0
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.oldest_message_age.id
    row      = 1
    column   = 6
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.messages_by_operation.id
    row      = 2
    column   = 0
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.messages_by_state.id
    row      = 2
    column   = 6
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.dlq_visible_messages.id
    row      = 3
    column   = 0
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.dlq_oldest_message_age.id
    row      = 3
    column   = 6
    width    = 6
    height   = 1
  }
}
