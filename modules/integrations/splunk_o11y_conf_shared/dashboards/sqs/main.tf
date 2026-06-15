resource "signalfx_single_value_chart" "queues" {
  name        = "# Queues"
  description = "Shows how many SQS queues are being monitored"

  program_text = "A = data('ApproximateAgeOfOldestMessage', rollup='latest').count(by=['QueueName']).count().publish(label='A')"

  max_precision   = 4
  unit_prefix     = "Metric"
  color_by        = "Dimension"
  show_spark_line = false

  viz_options {
    display_name = "Number of SQS queues monitored"
    label        = "A"
  }
}

resource "signalfx_list_chart" "top_queues_by_message_sent" {
  name        = "Top  queues by message sent"
  description = "Ranks queues by number of sent messages"

  program_text = "A = data('NumberOfMessagesSent', rollup='latest').sum(by=['QueueName']).top(count=5).publish(label='A')"
  sort_by      = "-value"

  disable_sampling        = false
  hide_missing_values     = true
  max_precision           = 4
  time_range              = 900
  unit_prefix             = "Metric"
  secondary_visualization = "None"

  legend_options_fields {
    enabled  = true
    property = "QueueName"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_originatingMetric"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_metric"
  }

  viz_options {
    display_name = "Top queues by visible messages"
    label        = "A"
  }
}

resource "signalfx_time_chart" "sent_message_size" {
  name        = "Sent message size"
  description = "Tracks the size of sent messages over time."

  program_text = <<-EOF
A = data('SentMessageSize', filter=filter('namespace', 'AWS/SQS')).sum(over=Args.get('ui.dashboard_window', '15m')).publish(label='A')
EOF

  plot_type        = "LineChart"
  disable_sampling = true
  show_event_lines = false
  stacked          = false
  time_range       = 900
  unit_prefix      = "Metric"

  axes_precision = 0

  axis_left {
    label = "Bytes"
  }

  histogram_options {
    color_theme = "gold"
  }

  legend_options_fields {
    enabled  = false
    property = "AWSUniqueId"
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
    enabled  = true
    property = "QueueName"
  }
  legend_options_fields {
    enabled  = false
    property = "stat"
  }

  viz_options {
    display_name = "Sent message size over time"
    label        = "A"
    value_unit   = "Byte"
  }
}

resource "signalfx_time_chart" "messages_by_state" {
  name        = "Messages by state"
  description = "Shows delayed, visible, and in-flight message breakdown."

  program_text = <<-EOF
A = data('ApproximateNumberOfMessagesDelayed', rollup='latest').sum().publish(label='A')
B = data('ApproximateNumberOfMessagesVisible', rollup='latest').sum().publish(label='B')
C = data('ApproximateNumberOfMessagesNotVisible', rollup='latest').sum().publish(label='C')
EOF

  plot_type        = "AreaChart"
  disable_sampling = false
  show_event_lines = false
  stacked          = true
  time_range       = 900
  unit_prefix      = "Metric"
  axes_precision   = 0

  on_chart_legend_dimension = "plot_label"

  axis_left {
    label = "#Messages"
  }

  histogram_options {
    color_theme = "gold"
  }

  viz_options {
    axis         = "left"
    color        = "blue"
    display_name = "Delayed messages"
    label        = "A"
    value_suffix = "No of messages"
  }
  viz_options {
    axis         = "left"
    color        = "emerald"
    display_name = "Visible messages"
    label        = "B"
    value_suffix = "No of messages"
  }
  viz_options {
    axis         = "left"
    color        = "pink"
    display_name = "In-flight messages"
    label        = "C"
    value_suffix = "No of messages"
  }
}

resource "signalfx_list_chart" "oldest_message_age" {
  name        = "Oldest message age"
  description = "Displays the max age of the oldest unprocessed message in seconds"

  program_text = "A = data('ApproximateAgeOfOldestMessage', filter=filter('namespace', 'AWS/SQS') and filter('stat', 'mean')).sum(by=['QueueName']).publish(label='A')"

  disable_sampling    = false
  hide_missing_values = true
  time_range          = 900
  unit_prefix         = "Metric"

  secondary_visualization = "None"
  sort_by                 = "-value"

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
    enabled  = true
    property = "QueueName"
  }
  legend_options_fields {
    enabled  = false
    property = "stat"
  }
  viz_options {
    display_name = "ApproximateAgeOfOldestMessage - Sum by QueueName"
    label        = "A"
  }
}

resource "signalfx_time_chart" "empty_receives" {
  name        = "# Empty receives"
  description = "Tracks ReceiveMessage API calls returning zero messages"

  program_text = "A = data('NumberOfEmptyReceives', rollup='latest').sum().publish(label='A')"

  plot_type        = "LineChart"
  disable_sampling = false
  show_event_lines = false
  stacked          = false
  time_range       = 900
  unit_prefix      = "Metric"
  axes_precision   = 0

  histogram_options {
    color_theme = "gold"
  }

  axis_left {
    label = "# Calls"
  }

  viz_options {
    axis         = "left"
    color        = "brown"
    display_name = "Number of empty receives"
    label        = "A"
    value_suffix = "No of receives"
  }
}

resource "signalfx_list_chart" "top_queues_by_message_received" {
  name        = "Top queues by message received"
  description = "Ranks queues by number of received messages"

  program_text = "A = data('NumberOfMessagesReceived', rollup='latest').sum(by=['QueueName']).top(count=5).publish(label='A')"

  sort_by = "-value"

  disable_sampling        = false
  hide_missing_values     = true
  max_precision           = 4
  time_range              = 900
  unit_prefix             = "Metric"
  secondary_visualization = "None"

  legend_options_fields {
    enabled  = true
    property = "QueueName"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_originatingMetric"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_metric"
  }

  viz_options {
    display_name = "Top queues by visible messages"
    label        = "A"
  }
}

resource "signalfx_time_chart" "message_processing_trend" {
  name        = "Message processing trend"
  description = "Tracks messages sent, received, and deleted over time."

  program_text = <<-EOF
A = data('NumberOfMessagesSent', rollup='latest').sum().publish(label='A')
B = data('NumberOfMessagesReceived', rollup='latest').sum().publish(label='B')
C = data('NumberOfMessagesDeleted', rollup='latest').sum().publish(label='C')
EOF

  plot_type        = "AreaChart"
  disable_sampling = false
  show_event_lines = false
  time_range       = 900
  unit_prefix      = "Metric"
  axes_precision   = 0

  on_chart_legend_dimension = "plot_label"

  axis_left {
    label = "Count"
  }

  histogram_options {
    color_theme = "gold"
  }


  viz_options {
    axis         = "left"
    color        = "azure"
    display_name = "Messages received"
    label        = "B"
    value_suffix = "No of messages"
  }
  viz_options {
    axis         = "left"
    color        = "blue"
    display_name = "Messages sent"
    label        = "A"
    value_suffix = "No of messages"
  }
  viz_options {
    axis         = "left"
    color        = "orange"
    display_name = "Messages deleted"
    label        = "C"
    value_suffix = "No of messages"
  }
}

resource "signalfx_time_chart" "messages_deleted" {
  name        = "# Messages deleted"
  description = "Displays messages successfully deleted from queues"

  program_text = "A = data('NumberOfMessagesDeleted', rollup='latest').sum().publish(label='A')"

  plot_type        = "LineChart"
  disable_sampling = false
  show_event_lines = false
  stacked          = false
  time_range       = 900
  unit_prefix      = "Metric"
  axes_precision   = 0

  axis_left {
    label = "# Messages"
  }

  histogram_options {
    color_theme = "gold"
  }
  viz_options {
    axis         = "left"
    color        = "emerald"
    display_name = "Number of messages deleted"
    label        = "A"
    value_suffix = "No of messages"
  }
}

resource "signalfx_time_chart" "dead_letter_backlog_trend" {
  name        = "DLQ backlog trend"
  description = "Tracks visible and in-flight messages in dead-letter queues."

  program_text = <<-EOF
A = data('ApproximateNumberOfMessagesVisible', filter=filter('namespace', 'AWS/SQS') and filter('QueueName', '*dead-letter*', '*dlq*', '*DLQ*') and filter('stat', 'mean'), rollup='latest').sum(by=['QueueName', 'aws_tag_TenantName']).publish(label='Visible')
B = data('ApproximateNumberOfMessagesNotVisible', filter=filter('namespace', 'AWS/SQS') and filter('QueueName', '*dead-letter*', '*dlq*', '*DLQ*') and filter('stat', 'mean'), rollup='latest').sum(by=['QueueName', 'aws_tag_TenantName']).publish(label='In-flight')
EOF

  plot_type                 = "AreaChart"
  axes_precision            = 0
  disable_sampling          = false
  on_chart_legend_dimension = "plot_label"
  show_event_lines          = false
  stacked                   = true
  time_range                = 900
  unit_prefix               = "Metric"

  axis_left {
    label = "# Messages"
  }

  legend_options_fields {
    enabled  = true
    property = "QueueName"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_tag_TenantName"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_metric"
  }
}

resource "signalfx_list_chart" "dead_letter_oldest_message_age" {
  name        = "DLQ oldest message age"
  description = "Ranks dead-letter queues by oldest message age."

  program_text = "A = data('ApproximateAgeOfOldestMessage', filter=filter('namespace', 'AWS/SQS') and filter('QueueName', '*dead-letter*', '*dlq*', '*DLQ*') and filter('stat', 'mean'), rollup='latest').max(by=['QueueName', 'aws_tag_TenantName']).top(count=20).publish(label='A')"
  sort_by      = "-value"

  disable_sampling        = false
  hide_missing_values     = true
  max_precision           = 4
  secondary_visualization = "None"
  time_range              = 900
  unit_prefix             = "Metric"

  legend_options_fields {
    enabled  = true
    property = "QueueName"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_tag_TenantName"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_metric"
  }

  viz_options {
    display_name = "Oldest DLQ message age"
    label        = "A"
    value_unit   = "Second"
  }
}

resource "signalfx_list_chart" "dead_letter_visible_messages" {
  name        = "DLQ visible messages"
  description = "Ranks dead-letter queues by visible backlog."

  program_text = "A = data('ApproximateNumberOfMessagesVisible', filter=filter('namespace', 'AWS/SQS') and filter('QueueName', '*dead-letter*', '*dlq*', '*DLQ*') and filter('stat', 'mean'), rollup='latest').sum(by=['QueueName', 'aws_tag_TenantName']).top(count=20).publish(label='A')"
  sort_by      = "-value"

  disable_sampling        = false
  hide_missing_values     = true
  max_precision           = 4
  secondary_visualization = "None"
  time_range              = 900
  unit_prefix             = "Metric"

  legend_options_fields {
    enabled  = true
    property = "QueueName"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_tag_TenantName"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_metric"
  }

  viz_options {
    display_name = "Visible DLQ messages"
    label        = "A"
  }
}

resource "signalfx_dashboard" "sqs" {
  name        = "SQS"
  description = "SQS queue counts, message states, sizes, and processing trends."

  dashboard_group = var.dashboard_group

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

  chart {
    chart_id = signalfx_time_chart.message_processing_trend.id
    column   = 4
    row      = 0
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.sent_message_size.id
    column   = 8
    row      = 0
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_single_value_chart.queues.id
    column   = 0
    row      = 0
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.top_queues_by_message_received.id
    column   = 0
    row      = 1
    width    = 4
    height   = 2
  }

  chart {
    chart_id = signalfx_list_chart.oldest_message_age.id
    column   = 8
    row      = 1
    width    = 4
    height   = 2
  }

  chart {
    chart_id = signalfx_list_chart.top_queues_by_message_sent.id
    column   = 4
    row      = 1
    width    = 4
    height   = 2
  }

  chart {
    chart_id = signalfx_time_chart.messages_deleted.id
    column   = 6
    row      = 3
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.messages_by_state.id
    column   = 0
    row      = 3
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.empty_receives.id
    column   = 0
    row      = 4
    width    = 12
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.dead_letter_backlog_trend.id
    column   = 0
    row      = 5
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.dead_letter_visible_messages.id
    column   = 4
    row      = 5
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.dead_letter_oldest_message_age.id
    column   = 8
    row      = 5
    width    = 4
    height   = 1
  }
}
