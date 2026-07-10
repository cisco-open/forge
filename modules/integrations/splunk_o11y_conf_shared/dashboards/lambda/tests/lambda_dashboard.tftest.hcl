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

run "lambda_dashboard_contract" {
  command = plan

  assert {
    condition = (
      signalfx_time_chart.invocations.name == "Invocations"
      && signalfx_time_chart.invocations.time_range == 900
      && strcontains(signalfx_time_chart.invocations.program_text, "Invocations")
      && signalfx_single_value_chart.total_errors.name == "Total errors"
      && strcontains(signalfx_time_chart.errors_by_version.program_text, "Errors")
    )
    error_message = "Lambda charts must keep invocation and error SignalFlow behavior."
  }
}

run "lambda_dashboard_wiring_contract" {
  command = plan

  assert {
    condition = (
      signalfx_dashboard.lambda.name == "Lambdas"
      && signalfx_dashboard.lambda.dashboard_group == "forge-dashboard-group"
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
