mock_provider "signalfx" {}

variables {
  tenant_names    = ["tenant-b", "tenant-a"]
  dashboard_group = "forge-dashboard-group"
  dynamic_variables = [
    {
      property               = "aws_region"
      alias                  = "AWS Region"
      description            = "Limit by AWS region"
      values                 = ["us-east-1"]
      value_required         = true
      values_suggested       = ["us-east-1", "us-west-2"]
      restricted_suggestions = true
    }
  ]
}

run "sqs_dashboard_contract" {
  command = plan

  assert {
    condition = (
      signalfx_single_value_chart.queues.name == "# Queues"
      && strcontains(signalfx_single_value_chart.queues.program_text, "ApproximateAgeOfOldestMessage")
      && signalfx_time_chart.message_processing_trend.name == "Message processing trend"
      && strcontains(signalfx_time_chart.dead_letter_backlog_trend.program_text, "ApproximateNumberOfMessagesVisible")
      && signalfx_list_chart.dead_letter_visible_messages.sort_by == "-value"
    )
    error_message = "SQS charts must keep queue-count, processing-trend, and dead-letter queue behavior."
  }
}

run "sqs_dashboard_wiring_contract" {
  command = plan

  assert {
    condition = (
      signalfx_dashboard.sqs.name == "SQS"
      && signalfx_dashboard.sqs.dashboard_group == "forge-dashboard-group"
      && length(signalfx_dashboard.sqs.chart) == 12
    )
    error_message = "SQS dashboard must keep its name, group input, and chart count."
  }

  assert {
    condition = alltrue([
      contains([for chart in signalfx_dashboard.sqs.chart : chart.chart_id], signalfx_time_chart.message_processing_trend.id),
      contains([for chart in signalfx_dashboard.sqs.chart : chart.chart_id], signalfx_list_chart.dead_letter_oldest_message_age.id),
    ])
    error_message = "SQS dashboard must keep its first and final chart wiring."
  }
}
