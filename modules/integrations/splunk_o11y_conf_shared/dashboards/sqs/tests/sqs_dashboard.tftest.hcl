mock_provider "signalfx" {}

variables {
  tenant_names    = ["acgw", "bcgw"]
  dashboard_group = "forge-dashboards"
}

run "sqs_dashboard_contract" {
  command = plan

  assert {
    condition = (
      signalfx_dashboard.sqs.name == "SQS"
      && signalfx_dashboard.sqs.dashboard_group == "forge-dashboards"
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
