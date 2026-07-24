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
      && signalfx_time_chart.invocations.time_range == 3600
      && strcontains(signalfx_time_chart.invocations.program_text, "Invocations")
      && signalfx_single_value_chart.total_errors.name == "Total errors"
      && strcontains(signalfx_single_value_chart.total_errors.program_text, ".sum(over='30m')")
      && strcontains(signalfx_single_value_chart.total_throttles.program_text, ".sum(over='30m')")
      && strcontains(signalfx_single_value_chart.total_invocations.program_text, ".sum(over='30m')")
      && strcontains(signalfx_time_chart.errors_by_version.program_text, "Errors")
      && strcontains(signalfx_time_chart.errors_by_version.program_text, ".sum(by=['aws_tag_TenantName', 'aws_function_name', 'aws_function_version'])")
      && strcontains(signalfx_list_chart.avg_duration_by_version.program_text, ".mean(by=['aws_tag_TenantName', 'aws_function_name', 'aws_function_version'])")
    )
    error_message = "Lambda charts must keep one-hour visibility and ingestion-delay-safe invocation, error, and throttle behavior."
  }

  assert {
    condition = alltrue([
      for program_text in [
        signalfx_list_chart.percent_invocations_by_version.program_text,
        signalfx_time_chart.errors_by_version.program_text,
        signalfx_list_chart.avg_duration_by_version.program_text,
        signalfx_time_chart.throttles_by_version.program_text,
        signalfx_time_chart.invocations_by_version.program_text,
        ] : (
        strcontains(program_text, "filter('aws_function_version', '*')")
        && strcontains(program_text, "aws_function_name")
        && !strcontains(program_text, "filter('ExecutedVersion', '*')")
      )
    ])
    error_message = "Standard Lambda version charts must use the live enriched function name and version properties instead of the sparse ExecutedVersion dimension."
  }
}

run "lambda_dashboard_wiring_contract" {
  command = plan

  assert {
    condition = (
      signalfx_dashboard.lambda.name == "Lambdas"
      && signalfx_dashboard.lambda.dashboard_group == "forge-dashboard-group"
      && signalfx_dashboard.lambda.variable[0].values == toset(["tenant-a", "tenant-b"])
      && signalfx_dashboard.lambda.variable[0].value_required
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
