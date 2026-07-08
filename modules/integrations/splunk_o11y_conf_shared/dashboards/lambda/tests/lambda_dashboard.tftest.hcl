mock_provider "signalfx" {}

variables {
  tenant_names    = ["acgw", "bcgw"]
  dashboard_group = "forge-dashboards"
}

run "lambda_dashboard_contract" {
  command = plan

  assert {
    condition = (
      signalfx_dashboard.lambda.name == "Lambdas"
      && signalfx_dashboard.lambda.dashboard_group == "forge-dashboards"
      && length(signalfx_dashboard.lambda.chart) == 15
    )
    error_message = "Lambda dashboard must keep its name, group input, and chart count."
  }

  assert {
    condition = alltrue([
      contains([for chart in signalfx_dashboard.lambda.chart : chart.chart_id], signalfx_time_chart.invocations.id),
      contains([for chart in signalfx_dashboard.lambda.chart : chart.chart_id], signalfx_time_chart.provisioned_concurrency_utilization.id),
    ])
    error_message = "Lambda dashboard must keep its first and final chart wiring."
  }
}
