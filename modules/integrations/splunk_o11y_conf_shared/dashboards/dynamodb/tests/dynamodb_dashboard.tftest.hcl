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

run "dynamodb_dashboard_contract" {
  command = plan

  assert {
    condition = (
      signalfx_time_chart.read_capacity_percentage.name == "Percentage of read capacity consumed"
      && signalfx_time_chart.read_capacity_percentage.time_range == 3600
      && strcontains(signalfx_time_chart.read_capacity_percentage.program_text, "ConsumedReadCapacityUnits")
      && signalfx_single_value_chart.throttled_requests_single.name == "Throttled requests"
      && strcontains(signalfx_time_chart.throttled_requests_ts.program_text, "ThrottledRequests")
    )
    error_message = "DynamoDB charts must keep capacity and throttling SignalFlow metrics."
  }
}

run "dynamodb_dashboard_wiring_contract" {
  command = plan

  assert {
    condition = (
      signalfx_dashboard.dynamodb.name == "DynamoDBs"
      && signalfx_dashboard.dynamodb.dashboard_group == "forge-dashboard-group"
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
