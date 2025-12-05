resource "signalfx_time_chart" "write_throttle_events" {
  name         = "Write throttle events"
  description  = "Requests to DynamoDB that exceed the provisioned write capacity units for a table or a global secondary index."
  program_text = <<-EOF
A = data('WriteThrottleEvents', filter=filter('namespace', 'AWS/DynamoDB') and filter('stat', 'sum') and filter('TableName', '*'), rollup='sum').publish(label='A')
EOF

  plot_type   = "AreaChart"
  unit_prefix = "Metric"
  color_by    = "Dimension"
  stacked     = true

  axes_precision = 0

  show_data_markers = true

  time_range = 900

  histogram_options {
    color_theme = "gold"
  }

  viz_options {
    axis         = "left"
    color        = "orange"
    display_name = "Writethrottleevents"
    label        = "A"
  }
}

resource "signalfx_time_chart" "system_errors_ts" {
  name         = "System errors"
  description  = "Requests to DynamoDB or Amazon DynamoDB streams that generate an HTTP 500 status code during the specified time period."
  program_text = <<-EOF
A = data('SystemErrors', filter=filter('namespace', 'AWS/DynamoDB') and filter('stat', 'sum') and filter('TableName', '*') and filter('Operation', '*'), rollup='sum').publish(label='A')
EOF

  plot_type   = "AreaChart"
  unit_prefix = "Metric"
  color_by    = "Dimension"
  stacked     = true

  axes_precision = 0

  time_range = 900

  histogram_options {
    color_theme = "gold"
  }

  viz_options {
    axis         = "left"
    display_name = "Systemerrors"
    label        = "A"
  }
}

resource "signalfx_time_chart" "read_capacity_percentage" {
  name         = "Percentage of read capacity consumed"
  description  = "The percentage of read capacity units consumed over the specified time period, so you can track how much of your provisioned throughput is used."
  program_text = <<-EOF
A = data('ProvisionedReadCapacityUnits', filter=filter('namespace', 'AWS/DynamoDB') and filter('stat', 'mean') and filter('TableName', '*')).publish(label='A', enable=False)
B = data('ConsumedReadCapacityUnits', filter=filter('namespace', 'AWS/DynamoDB') and filter('stat', 'mean') and filter('TableName', '*')).publish(label='B', enable=False)
C = ((B/A)*100).publish(label='C')
EOF

  plot_type   = "LineChart"
  unit_prefix = "Metric"
  color_by    = "Dimension"
  stacked     = false

  axes_precision            = 0
  on_chart_legend_dimension = "TableName"
  show_data_markers         = true
  time_range                = 3600

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
    enabled  = false
    property = "stat"
  }
  legend_options_fields {
    enabled  = true
    property = "TableName"
  }

  viz_options {
    axis         = "left"
    display_name = "Consumedreadcapacityunits"
    label        = "B"
  }
  viz_options {
    axis         = "left"
    display_name = "Percentage of read capacity consumed"
    label        = "C"
  }
  viz_options {
    axis         = "left"
    display_name = "Provisionedreadcapacityunits"
    label        = "A"
  }
}

resource "signalfx_time_chart" "returned_item_count" {
  name         = "Returned item count"
  description  = "The number of items returned by query or scan operations during the specified time period."
  program_text = <<-EOF
A = data('ReturnedItemCount', filter=filter('namespace', 'AWS/DynamoDB') and filter('TableName', '*') and filter('Operation', '*') and filter('stat', 'count'), rollup='sum').publish(label='A')
EOF

  plot_type   = "LineChart"
  unit_prefix = "Metric"
  color_by    = "Dimension"
  stacked     = false

  axes_precision = 0

  on_chart_legend_dimension = "Operation"

  show_data_markers = true
  time_range        = 3600

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
    enabled  = true
    property = "Operation"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_metric"
  }
  legend_options_fields {
    enabled  = false
    property = "stat"
  }
  legend_options_fields {
    enabled  = true
    property = "TableName"
  }

  viz_options {
    axis         = "left"
    display_name = "Returneditemcount"
    label        = "A"
  }
}

resource "signalfx_single_value_chart" "avg_request_latency_single" {
  name        = "Average request latency (ms)"
  description = "Successful requests to DynamoDB or Amazon DynamoDB streams during the specified time period."
  unit_prefix = "Metric"
  color_by    = "Dimension"

  max_precision = 3

  program_text = <<-EOF
A = data('SuccessfulRequestLatency', filter=filter('namespace', 'AWS/DynamoDB') and filter('stat', 'mean')).mean().publish(label='A')
EOF

  viz_options {
    display_name = "Successfulrequestlatency - mean"
    label        = "A"
  }
}

resource "signalfx_time_chart" "avg_request_latency_ts" {
  name         = "Average request latency (ms)"
  description  = "Successful requests to DynamoDB or Amazon DynamoDB streams during the specified time period."
  program_text = <<-EOF
A = data('SuccessfulRequestLatency', filter=filter('namespace', 'AWS/DynamoDB') and filter('stat', 'mean')).publish(label='A')
EOF

  axes_precision = 0

  on_chart_legend_dimension = "Operation"

  plot_type   = "LineChart"
  unit_prefix = "Metric"
  color_by    = "Dimension"
  stacked     = false

  show_data_markers = true
  time_range        = 3600

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
    enabled  = true
    property = "Operation"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_metric"
  }
  legend_options_fields {
    enabled  = false
    property = "stat"
  }
  legend_options_fields {
    enabled  = true
    property = "TableName"
  }

  viz_options {
    axis         = "left"
    display_name = "Successfulrequestlatency"
    label        = "A"
  }
}

resource "signalfx_single_value_chart" "throttled_requests_single" {
  name        = "Throttled requests"
  description = "Requests to DynamoDB that exceed the provisioned throughput limits on a resource (such as a table or an index)."
  unit_prefix = "Metric"
  color_by    = "Dimension"

  program_text = <<-EOF
A = data('ThrottledRequests', filter=filter('namespace', 'AWS/DynamoDB') and filter('stat', 'sum'), rollup='sum').sum().publish(label='A')
EOF
  viz_options {
    color        = "yellow"
    display_name = "Throttledrequests - sum"
    label        = "A"
  }
}

resource "signalfx_single_value_chart" "system_errors_single" {
  name        = "System errors"
  description = "Requests to DynamoDB or Amazon DynamoDB streams that generate an HTTP 500 status code during the specified time period."
  unit_prefix = "Metric"
  color_by    = "Dimension"

  program_text = <<-EOF
A = data('SystemErrors', filter=filter('namespace', 'AWS/DynamoDB') and filter('stat', 'sum') and filter('TableName', '*') and filter('Operation', '*'), rollup='sum').publish(label='A')
EOF

  viz_options {
    color        = "brown"
    display_name = "Systemerrors"
    label        = "A"
  }
}

resource "signalfx_time_chart" "user_errors_ts" {
  name         = "User errors"
  description  = "Requests to DynamoDB or Amazon DynamoDB streams that generate an HTTP 400 status code during the specified time period."
  program_text = <<-EOF
A = data('UserErrors', filter=filter('namespace', 'AWS/DynamoDB') and filter('sf_metric', 'UserErrors') and filter('stat', 'sum'), rollup='sum').publish(label='A')
EOF

  plot_type   = "ColumnChart"
  unit_prefix = "Metric"
  color_by    = "Dimension"
  stacked     = false

  axes_precision = 0

  show_data_markers = true

  time_range = 3600

  histogram_options {
    color_theme = "gold"
  }

  viz_options {
    axis         = "left"
    color        = "brown"
    display_name = "Usererrors"
    label        = "A"
  }
}

resource "signalfx_time_chart" "read_throttle_events" {
  name         = "Read throttle events"
  description  = "Requests to DynamoDB that exceed the provisioned read capacity units for a table or a global secondary index."
  program_text = <<-EOF
A = data('ReadThrottleEvents', filter=filter('stat', 'sum') and filter('TableName', '*'), rollup='sum').publish(label='A')
EOF

  plot_type   = "AreaChart"
  unit_prefix = "Metric"
  color_by    = "Dimension"
  stacked     = true

  axes_precision            = 0
  on_chart_legend_dimension = "TableName"
  show_data_markers         = true
  time_range                = 3600
  histogram_options {
    color_theme = "gold"
  }

  viz_options {
    axis         = "left"
    color        = "purple"
    display_name = "Readthrottleevents"
    label        = "A"
  }
}

resource "signalfx_time_chart" "throttled_requests_ts" {
  name         = "Throttled requests"
  description  = "Requests to DynamoDB that exceed the provisioned throughput limits on a resource (such as a table or an index)."
  program_text = <<-EOF
A = data('ThrottledRequests', filter=filter('namespace', 'AWS/DynamoDB') and filter('stat', 'sum'), rollup='sum').publish(label='A')
EOF

  plot_type   = "AreaChart"
  unit_prefix = "Metric"
  color_by    = "Dimension"
  stacked     = true

  axes_precision = 0

  on_chart_legend_dimension = "Operation"

  show_data_markers = true

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
    property = "sf_originatingMetric"
  }
  legend_options_fields {
    enabled  = false
    property = "namespace"
  }
  legend_options_fields {
    enabled  = true
    property = "Operation"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_metric"
  }
  legend_options_fields {
    enabled  = false
    property = "stat"
  }
  legend_options_fields {
    enabled  = true
    property = "TableName"
  }

  viz_options {
    axis         = "left"
    display_name = "Throttledrequests"
    label        = "A"
  }
}

resource "signalfx_time_chart" "write_capacity_percentage" {
  name         = "Percentage of write capacity consumed"
  description  = "The percentage of write capacity units consumed over the specified time period, so you can track how much of your provisioned throughput is used."
  program_text = <<-EOF
A = data('ProvisionedWriteCapacityUnits', filter=filter('namespace', 'AWS/DynamoDB') and filter('stat', 'mean') and filter('TableName', '*')).publish(label='A', enable=False)
B = data('ConsumedWriteCapacityUnits', filter=filter('namespace', 'AWS/DynamoDB') and filter('stat', 'mean') and filter('TableName', '*')).publish(label='B', enable=False)
C = ((B/A)*100).publish(label='C')
EOF

  plot_type   = "LineChart"
  unit_prefix = "Metric"
  color_by    = "Dimension"
  stacked     = false

  axes_precision = 0

  on_chart_legend_dimension = "TableName"

  show_data_markers = true

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
    property = "stat"
  }
  legend_options_fields {
    enabled  = true
    property = "TableName"
  }

  viz_options {
    axis         = "left"
    display_name = "Consumedwritecapacityunits"
    label        = "B"
  }
  viz_options {
    axis         = "left"
    display_name = "Percentage of write capacity consumed"
    label        = "C"
  }
  viz_options {
    axis         = "left"
    color        = "chartreuse"
    display_name = "Provisionedwritecapacityunits"
    label        = "A"
  }
}

resource "signalfx_single_value_chart" "user_errors_single" {
  name        = "User errors"
  description = "Requests to DynamoDB or DynamoDB streams that generate an HTTP 400 status code during the specified time period."
  unit_prefix = "Metric"
  color_by    = "Dimension"

  program_text = <<-EOF
A = data('UserErrors', filter=filter('namespace', 'AWS/DynamoDB') and filter('sf_metric', 'UserErrors') and filter('stat', 'sum'), rollup='sum').publish(label='A')
EOF

  viz_options {
    color        = "brown"
    display_name = "Usererrors"
    label        = "A"
  }
}


resource "signalfx_dashboard" "dynamodb" {
  name        = "DynamoDBs"
  description = "Forge CICD DynamoDB table performance, capacity, and throttling."

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

  chart {
    chart_id = signalfx_single_value_chart.avg_request_latency_single.id
    column   = 0
    row      = 0
    width    = 3
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.avg_request_latency_ts.id
    column   = 3
    row      = 0
    width    = 9
    height   = 1
  }

  chart {
    chart_id = signalfx_single_value_chart.throttled_requests_single.id
    column   = 0
    row      = 1
    width    = 3
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.throttled_requests_ts.id
    column   = 3
    row      = 1
    width    = 9
    height   = 1
  }

  chart {
    chart_id = signalfx_single_value_chart.user_errors_single.id
    column   = 9
    row      = 2
    width    = 3
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.user_errors_ts.id
    column   = 0
    row      = 2
    width    = 9
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.system_errors_ts.id
    column   = 0
    row      = 3
    width    = 9
    height   = 1
  }

  chart {
    chart_id = signalfx_single_value_chart.system_errors_single.id
    column   = 9
    row      = 3
    width    = 3
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.read_capacity_percentage.id
    column   = 0
    row      = 4
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.write_capacity_percentage.id
    column   = 6
    row      = 4
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.read_throttle_events.id
    column   = 0
    row      = 5
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.write_throttle_events.id
    column   = 6
    row      = 5
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.returned_item_count.id
    column   = 0
    row      = 6
    width    = 12
    height   = 1
  }
}
