mock_provider "signalfx" {
  mock_resource "signalfx_single_value_chart" {
    defaults = {
      id = "single-value-chart-id"
    }
  }
  mock_resource "signalfx_time_chart" {
    defaults = {
      id = "time-chart-id"
    }
  }
  mock_resource "signalfx_dashboard" {}
}

variables {
  dashboard_group         = "forge-dashboard-group"
  detector_id             = "runner-log-delivery-detector-id"
  lambda_dimension_filter = "filter('namespace', 'AWS/Lambda') and filter('Resource', '*') and (not filter('ExecutedVersion', '*'))"
  dynamic_variables = [
    {
      property               = "aws_account_id"
      alias                  = "AWS account"
      description            = "Forge AWS accounts."
      values                 = []
      value_required         = false
      values_suggested       = ["222222222222", "111111111111"]
      restricted_suggestions = true
    },
    {
      property               = "aws_region"
      alias                  = "AWS region"
      description            = "Forge AWS regions."
      values                 = []
      value_required         = false
      values_suggested       = ["us-west-2", "eu-west-1"]
      restricted_suggestions = true
    },
    {
      property               = "aws_tag_ProductFamilyName"
      alias                  = "Product family"
      description            = "Forge AWS product family."
      values                 = []
      value_required         = false
      values_suggested       = ["Forge MT"]
      restricted_suggestions = true
    },
  ]
}

run "creates_runner_logs_ingestion_dashboard" {
  command = plan

  assert {
    condition = (
      signalfx_dashboard.runner_logs_ingestion.name == "Forge Runner Logs Ingestion"
      && signalfx_dashboard.runner_logs_ingestion.dashboard_group == "forge-dashboard-group"
      && length(signalfx_dashboard.runner_logs_ingestion.chart) == 18
      && length(signalfx_dashboard.runner_logs_ingestion.variable) == 3
    )
    error_message = "The runner-log ingestion dashboard must keep its name, parent group, eighteen panels, and dedicated variables."
  }

  assert {
    condition = alltrue([
      for program_text in [
        signalfx_single_value_chart.visible_backlog.program_text,
        signalfx_single_value_chart.oldest_message.program_text,
        signalfx_single_value_chart.lambda_duration_guardrail.program_text,
        signalfx_single_value_chart.lambda_errors.program_text,
        signalfx_single_value_chart.kinesis_throttles.program_text,
        signalfx_single_value_chart.firehose_freshness.program_text,
        signalfx_time_chart.sqs_state.program_text,
        signalfx_time_chart.sqs_flow.program_text,
        signalfx_time_chart.lambda_concurrency.program_text,
        signalfx_time_chart.lambda_duration.program_text,
        signalfx_time_chart.lambda_failures.program_text,
        signalfx_time_chart.kinesis_records.program_text,
        signalfx_time_chart.kinesis_throughput.program_text,
        signalfx_time_chart.kinesis_iterator_age.program_text,
        signalfx_time_chart.oldest_message_trend.program_text,
        signalfx_time_chart.firehose_delivery.program_text,
        signalfx_time_chart.firehose_latency.program_text,
      ] :
      strcontains(program_text, "filter('aws_account_id', '111111111111')")
      && strcontains(program_text, "filter('aws_account_id', '222222222222')")
      && strcontains(program_text, "filter('aws_region', 'eu-west-1')")
      && strcontains(program_text, "filter('aws_region', 'us-west-2')")
      && strcontains(program_text, "filter('aws_tag_ProductFamilyName', 'Forge MT')")
      && strcontains(program_text, "not filter('aws_tag_TenantName', '*')")
    ])
    error_message = "Every runner-log ingestion panel must use the fail-closed Forge platform scope."
  }

  assert {
    condition = (
      strcontains(signalfx_time_chart.sqs_state.program_text, "splunk-s3-runner-logs-events")
      && strcontains(signalfx_time_chart.sqs_state.program_text, "splunk-s3-runner-logs-events-dlq")
      && strcontains(signalfx_time_chart.lambda_concurrency.program_text, "ConcurrentExecutions")
      && strcontains(signalfx_single_value_chart.lambda_duration_guardrail.program_text, "max(over='30m')")
      && strcontains(signalfx_time_chart.lambda_duration.program_text, "filter('stat', 'mean')")
      && strcontains(signalfx_time_chart.lambda_duration.program_text, "filter('stat', 'upper')")
      && signalfx_time_chart.lambda_duration.time_range == 21600
      && strcontains(signalfx_single_value_chart.lambda_errors.description, "timeouts")
      && strcontains(signalfx_time_chart.kinesis_throughput.program_text, "WriteProvisionedThroughputExceeded")
      && strcontains(signalfx_time_chart.kinesis_iterator_age.program_text, "GetRecords.IteratorAgeMilliseconds")
      && strcontains(signalfx_time_chart.oldest_message_trend.program_text, "ApproximateAgeOfOldestMessage")
      && signalfx_time_chart.oldest_message_trend.time_range == 21600
      && strcontains(signalfx_time_chart.firehose_delivery.program_text, "DeliveryToSplunk.Records")
      && strcontains(signalfx_time_chart.firehose_delivery.program_text, "filter('stat', 'mean')")
      && strcontains(signalfx_time_chart.firehose_delivery.program_text, "rollup='average'")
      && strcontains(signalfx_time_chart.firehose_delivery.program_text, ".mean(over='5m').mean(by=['aws_region', 'DeliveryStreamName'])")
      && strcontains(signalfx_time_chart.firehose_latency.program_text, "DeliveryToSplunk.DataFreshness")
      && strcontains(signalfx_time_chart.firehose_latency.program_text, "DeliveryToSplunk.DataAckLatency")
      && strcontains(signalfx_time_chart.delivery_health_alerts.program_text, "alerts(detector_id='runner-log-delivery-detector-id')")
      && signalfx_time_chart.delivery_health_alerts.show_event_lines
      && signalfx_time_chart.delivery_health_alerts.time_range == 3600
    )
    error_message = "The dashboard must preserve the detector events, SQS, Lambda, Kinesis, Splunk delivery, and tuning validation signals."
  }
}
