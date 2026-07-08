mock_provider "signalfx" {}

variables {
  tenant_names    = ["acgw", "bcgw"]
  dashboard_group = "forge-dashboards"
}

run "dynamodb_dashboard_contract" {
  command = plan

  assert {
    condition = (
      signalfx_dashboard.dynamodb.name == "DynamoDBs"
      && signalfx_dashboard.dynamodb.dashboard_group == "forge-dashboards"
      && length(signalfx_dashboard.dynamodb.chart) == 13
    )
    error_message = "DynamoDB dashboard must keep its name, group input, and chart count."
  }

  assert {
    condition = alltrue([
      contains([for chart in signalfx_dashboard.dynamodb.chart : chart.chart_id], signalfx_single_value_chart.avg_request_latency_single.id),
      contains([for chart in signalfx_dashboard.dynamodb.chart : chart.chart_id], signalfx_time_chart.returned_item_count.id),
    ])
    error_message = "DynamoDB dashboard must keep its first and final chart wiring."
  }
}
