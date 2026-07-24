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
      && strcontains(signalfx_time_chart.messages_by_state.program_text, "filter('stat', 'mean')")
      && strcontains(signalfx_time_chart.message_processing_trend.program_text, "filter('stat', 'sum')")
      && strcontains(signalfx_time_chart.message_processing_trend.program_text, "rollup='sum'")
      && signalfx_time_chart.message_processing_trend.time_range == 3600
      && strcontains(signalfx_list_chart.top_queues_by_message_sent.program_text, ".sum(over='30m')")
      && strcontains(signalfx_list_chart.top_queues_by_message_received.program_text, ".sum(over='30m')")
      && strcontains(signalfx_list_chart.oldest_message_age.program_text, ".max(by=['aws_tag_TenantName', 'QueueName'])")
      && signalfx_time_chart.message_processing_trend.name == "Message processing trend"
      && strcontains(signalfx_list_chart.visible_backlog_by_tenant.program_text, ".sum(by=['aws_tag_TenantName'])")
      && strcontains(signalfx_time_chart.dead_letter_backlog_trend.program_text, "ApproximateNumberOfMessagesVisible")
      && signalfx_list_chart.dead_letter_visible_messages.sort_by == "-value"
    )
    error_message = "SQS charts must keep one-hour visibility, ingestion-delay-safe counters, oldest-age, and dead-letter queue behavior."
  }
}

run "sqs_dashboard_wiring_contract" {
  command = plan

  assert {
    condition = (
      signalfx_dashboard.sqs.name == "Forge Tenant - SQS"
      && signalfx_dashboard.sqs.dashboard_group == "forge-dashboard-group"
      && signalfx_dashboard.sqs.variable[0].values == toset(["tenant-a", "tenant-b"])
      && signalfx_dashboard.sqs.variable[0].value_required
      && length(signalfx_dashboard.sqs.chart) == 13
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
