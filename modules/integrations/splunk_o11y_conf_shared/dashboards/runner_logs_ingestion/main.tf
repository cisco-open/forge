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

  aws_platform_filter = "(${local.aws_account_filter}) and (${local.aws_region_filter}) and (${local.product_family_filter}) and (not filter('aws_tag_TenantName', '*'))"
  queue_filter        = "filter('namespace', 'AWS/SQS') and filter('QueueName', 'splunk-s3-runner-logs-events')"
  dlq_filter          = "filter('namespace', 'AWS/SQS') and filter('QueueName', 'splunk-s3-runner-logs-events-dlq')"
  lambda_filter       = "(${var.lambda_dimension_filter}) and filter('aws_function_name', 'splunk-s3-runner-logs-lambda-*')"
  kinesis_filter      = "filter('namespace', 'AWS/Kinesis') and filter('StreamName', 'splunk-s3-runner-logs-stream-*')"
  firehose_filter     = "filter('namespace', 'AWS/Firehose') and filter('DeliveryStreamName', 'splunk-s3-runner-logs-firehose-*')"
}

resource "signalfx_single_value_chart" "visible_backlog" {
  name         = "Runner-log visible backlog"
  program_text = "A = data('ApproximateNumberOfMessagesVisible', filter=(${local.aws_platform_filter}) and (${local.queue_filter}) and filter('stat', 'upper'), rollup='latest').max(over='5m').sum().publish(label='A')"
  color_by     = "Dimension"

  viz_options {
    display_name = "Visible messages"
    label        = "A"
  }
}

resource "signalfx_single_value_chart" "oldest_message" {
  name         = "Runner-log oldest message"
  program_text = "A = data('ApproximateAgeOfOldestMessage', filter=(${local.aws_platform_filter}) and (${local.queue_filter}) and filter('stat', 'upper'), rollup='latest').max(over='5m').max().publish(label='A')"
  color_by     = "Dimension"

  viz_options {
    display_name = "Oldest message"
    label        = "A"
    value_unit   = "Second"
  }
}

resource "signalfx_single_value_chart" "lambda_duration_guardrail" {
  name                    = "Runner-log Lambda duration guardrail"
  description             = "Maximum duration over 30 minutes. This is a conservative guardrail for the 6-8 minute target because the AWS integration does not expose a native p99 statistic."
  program_text            = "A = data('Duration', filter=(${local.aws_platform_filter}) and (${local.lambda_filter}) and filter('stat', 'upper'), rollup='max').max(over='30m').max().publish(label='A')"
  color_by                = "Scale"
  secondary_visualization = "Sparkline"

  color_scale {
    color = "green"
    lt    = 360000
  }
  color_scale {
    color = "orange"
    gte   = 360000
    lt    = 480000
  }
  color_scale {
    color = "red"
    gte   = 480000
  }

  viz_options {
    display_name = "Maximum duration"
    label        = "A"
    value_unit   = "Millisecond"
  }
}

resource "signalfx_single_value_chart" "lambda_errors" {
  name         = "Runner-log Lambda errors/timeouts - sum(30m)"
  description  = "Lambda Errors includes invocation timeouts."
  program_text = "A = data('Errors', filter=(${local.aws_platform_filter}) and (${local.lambda_filter}) and filter('stat', 'sum'), rollup='sum', extrapolation='zero').sum(over='30m').sum().publish(label='A')"
  color_by     = "Dimension"

  viz_options {
    display_name = "Lambda errors/timeouts"
    label        = "A"
  }
}

resource "signalfx_single_value_chart" "kinesis_throttles" {
  name         = "Runner-log Kinesis throttles - sum(30m)"
  program_text = "A = data('WriteProvisionedThroughputExceeded', filter=(${local.aws_platform_filter}) and (${local.kinesis_filter}) and filter('stat', 'sum'), rollup='sum', extrapolation='zero').sum(over='30m').sum().publish(label='A')"
  color_by     = "Dimension"

  viz_options {
    display_name = "Kinesis write throttles"
    label        = "A"
  }
}

resource "signalfx_single_value_chart" "firehose_freshness" {
  name         = "Runner-log Splunk delivery freshness"
  program_text = "A = data('DeliveryToSplunk.DataFreshness', filter=(${local.aws_platform_filter}) and (${local.firehose_filter}) and filter('stat', 'upper'), rollup='max').max(over='5m').max().publish(label='A')"
  color_by     = "Dimension"

  viz_options {
    display_name = "Delivery freshness"
    label        = "A"
    value_unit   = "Second"
  }
}

resource "signalfx_time_chart" "delivery_health_alerts" {
  name             = "Runner-log delivery alerts"
  description      = "Detector events for Firehose delivery failures, stale delivery, and runner-log DLQ occupancy."
  program_text     = "A = alerts(detector_id='${var.detector_id}').publish(label='Runner-log delivery alerts')"
  plot_type        = "LineChart"
  show_event_lines = true
  time_range       = 3600
}

resource "signalfx_time_chart" "sqs_state" {
  name             = "Runner-log queue state"
  description      = "Visible, in-flight, and dead-letter runner-log messages by AWS region."
  program_text     = <<-EOF
visible = data('ApproximateNumberOfMessagesVisible', filter=(${local.aws_platform_filter}) and (${local.queue_filter}) and filter('stat', 'upper'), rollup='latest').max(over='5m').sum(by=['aws_region']).publish(label='A')
in_flight = data('ApproximateNumberOfMessagesNotVisible', filter=(${local.aws_platform_filter}) and (${local.queue_filter}) and filter('stat', 'upper'), rollup='latest').max(over='5m').sum(by=['aws_region']).publish(label='B')
dlq = data('ApproximateNumberOfMessagesVisible', filter=(${local.aws_platform_filter}) and (${local.dlq_filter}) and filter('stat', 'upper'), rollup='latest').max(over='5m').sum(by=['aws_region']).publish(label='C')
EOF
  plot_type        = "LineChart"
  disable_sampling = true
  time_range       = 3600

  viz_options {
    display_name = "Visible"
    label        = "A"
  }
  viz_options {
    display_name = "In flight"
    label        = "B"
  }
  viz_options {
    display_name = "DLQ"
    label        = "C"
  }
}

resource "signalfx_time_chart" "sqs_flow" {
  name             = "Runner-log queue flow"
  description      = "Runner-log messages sent, received, and deleted per five minutes."
  program_text     = <<-EOF
sent = data('NumberOfMessagesSent', filter=(${local.aws_platform_filter}) and (${local.queue_filter}) and filter('stat', 'sum'), rollup='sum', extrapolation='zero').sum(over='5m').sum(by=['aws_region']).publish(label='A')
received = data('NumberOfMessagesReceived', filter=(${local.aws_platform_filter}) and (${local.queue_filter}) and filter('stat', 'sum'), rollup='sum', extrapolation='zero').sum(over='5m').sum(by=['aws_region']).publish(label='B')
deleted = data('NumberOfMessagesDeleted', filter=(${local.aws_platform_filter}) and (${local.queue_filter}) and filter('stat', 'sum'), rollup='sum', extrapolation='zero').sum(over='5m').sum(by=['aws_region']).publish(label='C')
EOF
  plot_type        = "LineChart"
  disable_sampling = true
  time_range       = 3600

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

resource "signalfx_time_chart" "lambda_concurrency" {
  name         = "Runner-log Lambda concurrent executions"
  description  = "Maximum concurrent runner-log Lambda executions by AWS region."
  program_text = "A = data('ConcurrentExecutions', filter=(${local.aws_platform_filter}) and (${local.lambda_filter}) and filter('stat', 'upper'), rollup='max').max(over='5m').max(by=['aws_region', 'aws_function_name']).publish(label='A')"
  plot_type    = "LineChart"
  time_range   = 3600

  viz_options {
    display_name = "Concurrent executions"
    label        = "A"
  }
}

resource "signalfx_time_chart" "lambda_duration" {
  name         = "Runner-log Lambda duration"
  description  = "Mean and maximum runner-log Lambda execution duration by AWS region. Keep maximum below 6 minutes where possible and below 8 minutes as the operational guardrail."
  program_text = <<-EOF
average = data('Duration', filter=(${local.aws_platform_filter}) and (${local.lambda_filter}) and filter('stat', 'mean'), rollup='average').mean(over='5m').mean(by=['aws_region', 'aws_function_name']).publish(label='A')
maximum = data('Duration', filter=(${local.aws_platform_filter}) and (${local.lambda_filter}) and filter('stat', 'upper'), rollup='max').max(over='5m').max(by=['aws_region', 'aws_function_name']).publish(label='B')
EOF
  plot_type    = "LineChart"
  time_range   = 21600

  viz_options {
    display_name = "Average duration"
    label        = "A"
    value_unit   = "Millisecond"
  }
  viz_options {
    display_name = "Maximum duration"
    label        = "B"
    value_unit   = "Millisecond"
  }
}

resource "signalfx_time_chart" "lambda_failures" {
  name             = "Runner-log Lambda errors and throttles"
  description      = "Runner-log Lambda errors and throttles per five minutes."
  program_text     = <<-EOF
errors = data('Errors', filter=(${local.aws_platform_filter}) and (${local.lambda_filter}) and filter('stat', 'sum'), rollup='sum', extrapolation='zero').sum(over='5m').sum(by=['aws_region', 'aws_function_name']).publish(label='A')
throttles = data('Throttles', filter=(${local.aws_platform_filter}) and (${local.lambda_filter}) and filter('stat', 'sum'), rollup='sum', extrapolation='zero').sum(over='5m').sum(by=['aws_region', 'aws_function_name']).publish(label='B')
EOF
  plot_type        = "ColumnChart"
  disable_sampling = true
  time_range       = 3600

  viz_options {
    display_name = "Errors"
    label        = "A"
  }
  viz_options {
    display_name = "Throttles"
    label        = "B"
  }
}

resource "signalfx_time_chart" "kinesis_records" {
  name             = "Runner-log Kinesis records"
  description      = "Incoming records and successful PutRecords operations per five minutes."
  program_text     = <<-EOF
incoming = data('IncomingRecords', filter=(${local.aws_platform_filter}) and (${local.kinesis_filter}) and filter('stat', 'sum'), rollup='sum', extrapolation='zero').sum(over='5m').sum(by=['aws_region', 'StreamName']).publish(label='A')
successful_puts = data('PutRecords.Success', filter=(${local.aws_platform_filter}) and (${local.kinesis_filter}) and filter('stat', 'sum'), rollup='sum', extrapolation='zero').sum(over='5m').sum(by=['aws_region', 'StreamName']).publish(label='B')
EOF
  plot_type        = "LineChart"
  disable_sampling = true
  time_range       = 3600

  viz_options {
    display_name = "Incoming records"
    label        = "A"
  }
  viz_options {
    display_name = "Successful PutRecords calls"
    label        = "B"
  }
}

resource "signalfx_time_chart" "kinesis_throughput" {
  name             = "Runner-log Kinesis throughput exceeded"
  description      = "Kinesis read and write throttling counts per five minutes."
  program_text     = <<-EOF
read = data('ReadProvisionedThroughputExceeded', filter=(${local.aws_platform_filter}) and (${local.kinesis_filter}) and filter('stat', 'sum'), rollup='sum', extrapolation='zero').sum(over='5m').sum(by=['aws_region', 'StreamName']).publish(label='A')
write = data('WriteProvisionedThroughputExceeded', filter=(${local.aws_platform_filter}) and (${local.kinesis_filter}) and filter('stat', 'sum'), rollup='sum', extrapolation='zero').sum(over='5m').sum(by=['aws_region', 'StreamName']).publish(label='B')
EOF
  plot_type        = "ColumnChart"
  disable_sampling = true
  time_range       = 3600

  viz_options {
    display_name = "Read throughput exceeded"
    label        = "A"
  }
  viz_options {
    display_name = "Write throughput exceeded"
    label        = "B"
  }
}

resource "signalfx_time_chart" "kinesis_iterator_age" {
  name         = "Runner-log Kinesis iterator age"
  description  = "Maximum lag across all GetRecords consumers on the runner-log stream. Use the Firehose source-reader lag panel to isolate the managed Firehose consumer."
  program_text = "A = data('GetRecords.IteratorAgeMilliseconds', filter=(${local.aws_platform_filter}) and (${local.kinesis_filter}) and filter('stat', 'upper'), rollup='max').max(over='5m').max(by=['aws_region', 'StreamName']).publish(label='A')"
  plot_type    = "LineChart"
  time_range   = 3600

  viz_options {
    display_name = "Iterator age"
    label        = "A"
    value_unit   = "Millisecond"
  }
}

resource "signalfx_time_chart" "firehose_source_lag" {
  name         = "Runner-log Firehose source-reader lag"
  description  = "Firehose-specific distance from the newest record in the source Kinesis stream. This distinguishes a managed Firehose reader pause from another Kinesis consumer."
  program_text = "A = data('KinesisMillisBehindLatest', filter=(${local.aws_platform_filter}) and (${local.firehose_filter}) and filter('stat', 'upper'), rollup='max').max(over='5m').max(by=['aws_region', 'DeliveryStreamName']).publish(label='A')"
  plot_type    = "LineChart"
  time_range   = 21600

  viz_options {
    display_name = "Firehose source lag"
    label        = "A"
    value_unit   = "Millisecond"
  }
}

resource "signalfx_time_chart" "firehose_source_reads" {
  name             = "Runner-log Firehose source reads"
  description      = "Records and bytes read by Firehose from the source Kinesis stream per five minutes."
  program_text     = <<-EOF
records = data('DataReadFromKinesisStream.Records', filter=(${local.aws_platform_filter}) and (${local.firehose_filter}) and filter('stat', 'sum'), rollup='sum', extrapolation='zero').sum(over='5m').sum(by=['aws_region', 'DeliveryStreamName']).publish(label='A')
bytes = data('DataReadFromKinesisStream.Bytes', filter=(${local.aws_platform_filter}) and (${local.firehose_filter}) and filter('stat', 'sum'), rollup='sum', extrapolation='zero').sum(over='5m').sum(by=['aws_region', 'DeliveryStreamName']).publish(label='B')
EOF
  plot_type        = "LineChart"
  disable_sampling = true
  time_range       = 21600

  viz_options {
    axis         = "left"
    display_name = "Records read"
    label        = "A"
  }
  viz_options {
    axis         = "right"
    display_name = "Bytes read"
    label        = "B"
    value_unit   = "Byte"
  }
}

resource "signalfx_time_chart" "firehose_source_throttles" {
  name             = "Runner-log Firehose source throttles"
  description      = "Firehose GetRecords and GetShardIterator throttling against the source Kinesis stream per five minutes."
  program_text     = <<-EOF
get_records = data('ThrottledGetRecords', filter=(${local.aws_platform_filter}) and (${local.firehose_filter}) and filter('stat', 'sum'), rollup='sum', extrapolation='zero').sum(over='5m').sum(by=['aws_region', 'DeliveryStreamName']).publish(label='A')
get_shard_iterator = data('ThrottledGetShardIterator', filter=(${local.aws_platform_filter}) and (${local.firehose_filter}) and filter('stat', 'sum'), rollup='sum', extrapolation='zero').sum(over='5m').sum(by=['aws_region', 'DeliveryStreamName']).publish(label='B')
EOF
  plot_type        = "ColumnChart"
  disable_sampling = true
  time_range       = 21600

  viz_options {
    display_name = "GetRecords throttled"
    label        = "A"
  }
  viz_options {
    display_name = "GetShardIterator throttled"
    label        = "B"
  }
}

resource "signalfx_time_chart" "oldest_message_trend" {
  name         = "Runner-log oldest message age - 6h trend"
  description  = "Maximum source-queue message age by AWS region. After tuning, the sustained trend should decline rather than repeatedly reset and grow."
  program_text = "A = data('ApproximateAgeOfOldestMessage', filter=(${local.aws_platform_filter}) and (${local.queue_filter}) and filter('stat', 'upper'), rollup='max').max(over='5m').max(by=['aws_region']).publish(label='A')"
  plot_type    = "LineChart"
  time_range   = 21600

  viz_options {
    display_name = "Oldest message age"
    label        = "A"
    value_unit   = "Second"
  }
}

resource "signalfx_time_chart" "firehose_delivery" {
  name             = "Runner-log delivery to Splunk"
  description      = "Records sent to Splunk and the average Firehose delivery success percentage per five minutes. Interpret success only while records are flowing."
  program_text     = <<-EOF
records = data('DeliveryToSplunk.Records', filter=(${local.aws_platform_filter}) and (${local.firehose_filter}) and filter('stat', 'sum'), rollup='sum', extrapolation='zero').sum(over='5m').sum(by=['aws_region', 'DeliveryStreamName']).publish(label='A')
success = data('DeliveryToSplunk.Success', filter=(${local.aws_platform_filter}) and (${local.firehose_filter}) and filter('stat', 'mean'), rollup='average').mean(over='5m').mean(by=['aws_region', 'DeliveryStreamName']).publish(label='B')
EOF
  plot_type        = "LineChart"
  disable_sampling = true
  time_range       = 3600

  viz_options {
    display_name = "Delivered records"
    label        = "A"
  }
  viz_options {
    display_name = "Delivery success"
    label        = "B"
    value_suffix = "%"
  }
}

resource "signalfx_time_chart" "firehose_latency" {
  name         = "Runner-log Splunk delivery freshness and ACK latency"
  description  = "Oldest undelivered runner-log record age and Splunk acknowledgement latency."
  program_text = <<-EOF
freshness = data('DeliveryToSplunk.DataFreshness', filter=(${local.aws_platform_filter}) and (${local.firehose_filter}) and filter('stat', 'upper'), rollup='max').max(over='5m').max(by=['aws_region', 'DeliveryStreamName']).publish(label='A')
ack_latency = data('DeliveryToSplunk.DataAckLatency', filter=(${local.aws_platform_filter}) and (${local.firehose_filter}) and filter('stat', 'upper'), rollup='max').max(over='5m').max(by=['aws_region', 'DeliveryStreamName']).publish(label='B')
EOF
  plot_type    = "LineChart"
  time_range   = 3600

  viz_options {
    display_name = "Data freshness"
    label        = "A"
    value_unit   = "Second"
  }
  viz_options {
    display_name = "ACK latency"
    label        = "B"
    value_unit   = "Second"
  }
}

resource "terraform_data" "dashboard_parent" {
  triggers_replace = var.dashboard_group
}

resource "signalfx_dashboard" "runner_logs_ingestion" {
  name            = "Forge Runner Logs Ingestion"
  description     = "End-to-end health of the Forge runner-log ingestion path from SQS through Lambda and Kinesis to Firehose and Splunk HEC."
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
    chart_id = signalfx_single_value_chart.visible_backlog.id
    row      = 0
    column   = 0
    width    = 2
    height   = 1
  }
  chart {
    chart_id = signalfx_single_value_chart.oldest_message.id
    row      = 0
    column   = 2
    width    = 2
    height   = 1
  }
  chart {
    chart_id = signalfx_single_value_chart.lambda_duration_guardrail.id
    row      = 0
    column   = 4
    width    = 2
    height   = 1
  }
  chart {
    chart_id = signalfx_single_value_chart.lambda_errors.id
    row      = 0
    column   = 6
    width    = 2
    height   = 1
  }
  chart {
    chart_id = signalfx_single_value_chart.kinesis_throttles.id
    row      = 0
    column   = 8
    width    = 2
    height   = 1
  }
  chart {
    chart_id = signalfx_single_value_chart.firehose_freshness.id
    row      = 0
    column   = 10
    width    = 2
    height   = 1
  }
  chart {
    chart_id = signalfx_time_chart.delivery_health_alerts.id
    row      = 1
    column   = 0
    width    = 12
    height   = 1
  }
  chart {
    chart_id = signalfx_time_chart.sqs_state.id
    row      = 2
    column   = 0
    width    = 6
    height   = 1
  }
  chart {
    chart_id = signalfx_time_chart.sqs_flow.id
    row      = 2
    column   = 6
    width    = 6
    height   = 1
  }
  chart {
    chart_id = signalfx_time_chart.lambda_concurrency.id
    row      = 3
    column   = 0
    width    = 4
    height   = 1
  }
  chart {
    chart_id = signalfx_time_chart.lambda_duration.id
    row      = 3
    column   = 4
    width    = 4
    height   = 1
  }
  chart {
    chart_id = signalfx_time_chart.lambda_failures.id
    row      = 3
    column   = 8
    width    = 4
    height   = 1
  }
  chart {
    chart_id = signalfx_time_chart.kinesis_records.id
    row      = 4
    column   = 0
    width    = 4
    height   = 1
  }
  chart {
    chart_id = signalfx_time_chart.kinesis_throughput.id
    row      = 4
    column   = 4
    width    = 4
    height   = 1
  }
  chart {
    chart_id = signalfx_time_chart.kinesis_iterator_age.id
    row      = 4
    column   = 8
    width    = 4
    height   = 1
  }
  chart {
    chart_id = signalfx_time_chart.firehose_delivery.id
    row      = 5
    column   = 0
    width    = 6
    height   = 1
  }
  chart {
    chart_id = signalfx_time_chart.firehose_latency.id
    row      = 5
    column   = 6
    width    = 6
    height   = 1
  }
  chart {
    chart_id = signalfx_time_chart.oldest_message_trend.id
    row      = 7
    column   = 0
    width    = 12
    height   = 1
  }
  chart {
    chart_id = signalfx_time_chart.firehose_source_lag.id
    row      = 6
    column   = 0
    width    = 4
    height   = 1
  }
  chart {
    chart_id = signalfx_time_chart.firehose_source_reads.id
    row      = 6
    column   = 4
    width    = 4
    height   = 1
  }
  chart {
    chart_id = signalfx_time_chart.firehose_source_throttles.id
    row      = 6
    column   = 8
    width    = 4
    height   = 1
  }
}
