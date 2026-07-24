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

  aws_platform_filter      = "(${local.aws_account_filter}) and (${local.aws_region_filter}) and (${local.product_family_filter})"
  control_plane_filter     = "(${local.aws_platform_filter}) and (not filter('aws_tag_TenantName', '*'))"
  kinesis_dimension_filter = "filter('namespace', 'AWS/Kinesis') and filter('StreamName', '*')"
}

resource "signalfx_single_value_chart" "stream_count" {
  name        = "# Control-plane streams"
  description = "Number of Forge Kinesis streams without the TenantName tag in the selected AWS scope."

  program_text = "A = data('GetRecords.Success', filter=(${local.control_plane_filter}) and (${local.kinesis_dimension_filter}) and filter('stat', 'sum'), rollup='sum', extrapolation='zero').count(by=['StreamName']).count().publish(label='A')"

  color_by = "Dimension"

  viz_options {
    display_name = "Control-plane streams"
    label        = "A"
  }
}

resource "signalfx_time_chart" "incoming_records" {
  name        = "Incoming records by control-plane stream"
  description = "Five-minute count of records successfully written to each Forge control-plane Kinesis stream."

  program_text = "A = data('IncomingRecords', filter=(${local.control_plane_filter}) and (${local.kinesis_dimension_filter}) and filter('stat', 'sum'), rollup='sum', extrapolation='zero').sum(over='5m').sum(by=['aws_region', 'StreamName']).publish(label='A')"

  plot_type                 = "LineChart"
  axes_precision            = 0
  disable_sampling          = true
  on_chart_legend_dimension = "StreamName"
  time_range                = 3600

  axis_left {
    label     = "Records / 5m"
    min_value = 0
  }

  legend_options_fields {
    enabled  = true
    property = "aws_region"
  }

  legend_options_fields {
    enabled  = true
    property = "StreamName"
  }

  viz_options {
    display_name = "Incoming records"
    label        = "A"
  }
}

resource "signalfx_time_chart" "incoming_bytes" {
  name        = "Incoming bytes by control-plane stream"
  description = "Five-minute byte volume successfully written to each Forge control-plane Kinesis stream."

  program_text = "A = data('IncomingBytes', filter=(${local.control_plane_filter}) and (${local.kinesis_dimension_filter}) and filter('stat', 'sum'), rollup='sum', extrapolation='zero').sum(over='5m').sum(by=['aws_region', 'StreamName']).publish(label='A')"

  plot_type                 = "LineChart"
  axes_precision            = 0
  disable_sampling          = true
  on_chart_legend_dimension = "StreamName"
  time_range                = 3600

  axis_left {
    label     = "Bytes / 5m"
    min_value = 0
  }

  legend_options_fields {
    enabled  = true
    property = "aws_region"
  }

  legend_options_fields {
    enabled  = true
    property = "StreamName"
  }

  viz_options {
    display_name = "Incoming bytes"
    label        = "A"
    value_unit   = "Byte"
  }
}

resource "signalfx_time_chart" "throughput_exceeded" {
  name        = "Read and write throughput exceeded"
  description = "Five-minute Kinesis read and write throttling counts by Forge control-plane stream."

  program_text = <<-EOF
read_exceeded = data('ReadProvisionedThroughputExceeded', filter=(${local.control_plane_filter}) and (${local.kinesis_dimension_filter}) and filter('stat', 'sum'), rollup='sum', extrapolation='zero').sum(over='5m').sum(by=['aws_region', 'StreamName']).publish(label='A')
write_exceeded = data('WriteProvisionedThroughputExceeded', filter=(${local.control_plane_filter}) and (${local.kinesis_dimension_filter}) and filter('stat', 'sum'), rollup='sum', extrapolation='zero').sum(over='5m').sum(by=['aws_region', 'StreamName']).publish(label='B')
EOF

  plot_type                 = "ColumnChart"
  axes_precision            = 0
  disable_sampling          = true
  on_chart_legend_dimension = "StreamName"
  time_range                = 3600

  axis_left {
    label     = "Throttled operations / 5m"
    min_value = 0
  }

  legend_options_fields {
    enabled  = true
    property = "aws_region"
  }

  legend_options_fields {
    enabled  = true
    property = "StreamName"
  }

  viz_options {
    display_name = "Read throughput exceeded"
    label        = "A"
  }

  viz_options {
    display_name = "Write throughput exceeded"
    label        = "B"
  }
}

resource "signalfx_time_chart" "iterator_age" {
  name        = "GetRecords iterator age"
  description = "Maximum consumer lag in milliseconds. Zero means consumers are caught up with the stream."

  program_text = "A = data('GetRecords.IteratorAgeMilliseconds', filter=(${local.control_plane_filter}) and (${local.kinesis_dimension_filter}) and filter('stat', 'upper'), rollup='max').max(over='5m').max(by=['aws_region', 'StreamName']).publish(label='A')"

  plot_type                 = "LineChart"
  axes_precision            = 0
  disable_sampling          = true
  on_chart_legend_dimension = "StreamName"
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
    property = "StreamName"
  }

  viz_options {
    display_name = "Iterator age"
    label        = "A"
    value_unit   = "Millisecond"
  }
}

resource "signalfx_time_chart" "successful_operations" {
  name        = "Successful read and write operations"
  description = "Five-minute successful GetRecords and PutRecords operations by Forge control-plane stream."

  program_text = <<-EOF
get_records = data('GetRecords.Success', filter=(${local.control_plane_filter}) and (${local.kinesis_dimension_filter}) and filter('stat', 'sum'), rollup='sum', extrapolation='zero').sum(over='5m').sum(by=['aws_region', 'StreamName']).publish(label='A')
put_records = data('PutRecords.Success', filter=(${local.control_plane_filter}) and (${local.kinesis_dimension_filter}) and filter('stat', 'sum'), rollup='sum', extrapolation='zero').sum(over='5m').sum(by=['aws_region', 'StreamName']).publish(label='B')
EOF

  plot_type                 = "LineChart"
  axes_precision            = 0
  disable_sampling          = true
  on_chart_legend_dimension = "StreamName"
  time_range                = 3600

  axis_left {
    label     = "Operations / 5m"
    min_value = 0
  }

  legend_options_fields {
    enabled  = true
    property = "aws_region"
  }

  legend_options_fields {
    enabled  = true
    property = "StreamName"
  }

  viz_options {
    display_name = "GetRecords success"
    label        = "A"
  }

  viz_options {
    display_name = "PutRecords success"
    label        = "B"
  }
}

resource "signalfx_time_chart" "get_records_latency" {
  name        = "Average GetRecords latency"
  description = "Five-minute average GetRecords latency by Forge control-plane stream."

  program_text = "A = data('GetRecords.Latency', filter=(${local.control_plane_filter}) and (${local.kinesis_dimension_filter}) and filter('stat', 'mean'), rollup='average').mean(over='5m').mean(by=['aws_region', 'StreamName']).publish(label='A')"

  plot_type                 = "LineChart"
  axes_precision            = 0
  disable_sampling          = true
  on_chart_legend_dimension = "StreamName"
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
    property = "StreamName"
  }

  viz_options {
    display_name = "GetRecords latency"
    label        = "A"
    value_unit   = "Millisecond"
  }
}

resource "signalfx_time_chart" "put_records_latency" {
  name        = "Average PutRecord and PutRecords latency"
  description = "Five-minute average PutRecord and PutRecords latency by Forge control-plane stream."

  program_text = <<-EOF
put_record = data('PutRecord.Latency', filter=(${local.control_plane_filter}) and (${local.kinesis_dimension_filter}) and filter('stat', 'mean'), rollup='average').mean(over='5m').mean(by=['aws_region', 'StreamName']).publish(label='A')
put_records = data('PutRecords.Latency', filter=(${local.control_plane_filter}) and (${local.kinesis_dimension_filter}) and filter('stat', 'mean'), rollup='average').mean(over='5m').mean(by=['aws_region', 'StreamName']).publish(label='B')
EOF

  plot_type                 = "LineChart"
  axes_precision            = 0
  disable_sampling          = true
  on_chart_legend_dimension = "StreamName"
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
    property = "StreamName"
  }

  viz_options {
    display_name = "PutRecord latency"
    label        = "A"
    value_unit   = "Millisecond"
  }

  viz_options {
    display_name = "PutRecords latency"
    label        = "B"
    value_unit   = "Millisecond"
  }
}

resource "terraform_data" "dashboard_parent" {
  triggers_replace = var.dashboard_group
}

resource "signalfx_dashboard" "kinesis_control_plane" {
  name            = "Forge Control Plane - Kinesis"
  description     = "Health and activity for Forge Kinesis streams that are not assigned to a tenant."
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
    chart_id = signalfx_single_value_chart.stream_count.id
    row      = 0
    column   = 0
    width    = 12
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.incoming_records.id
    row      = 1
    column   = 0
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.incoming_bytes.id
    row      = 1
    column   = 6
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.throughput_exceeded.id
    row      = 2
    column   = 0
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.iterator_age.id
    row      = 2
    column   = 6
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.successful_operations.id
    row      = 3
    column   = 0
    width    = 12
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.get_records_latency.id
    row      = 4
    column   = 0
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.put_records_latency.id
    row      = 4
    column   = 6
    width    = 6
    height   = 1
  }
}
