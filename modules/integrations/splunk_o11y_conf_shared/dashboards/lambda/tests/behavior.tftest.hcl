mock_provider "signalfx" {}

variables {
  tenant_names            = ["tenant-b", "tenant-a"]
  dashboard_group         = "forge-dashboard-group"
  lambda_dimension_filter = "filter('namespace', 'AWS/Lambda') and filter('Resource', '*') and (not filter('ExecutedVersion', '*'))"
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
      && alltrue([
        for field in signalfx_time_chart.invocations.legend_options_fields :
        !field.enabled
      ])
      && signalfx_single_value_chart.total_errors.name == "Total errors"
      && signalfx_single_value_chart.avg_invocation_duration.description == "Average over selected window."
      && alltrue([
        for program_text in [
          signalfx_single_value_chart.total_errors.program_text,
          signalfx_single_value_chart.total_throttles.program_text,
          signalfx_single_value_chart.total_invocations.program_text,
        ] : strcontains(program_text, ".sum(over='1h')")
      ])
      && strcontains(signalfx_time_chart.errors_by_version.program_text, "Errors")
      && strcontains(signalfx_time_chart.errors_by_version.program_text, ".sum(by=['aws_tag_TenantName', 'aws_function_name', 'aws_tag_ForgeModuleRef'])")
      && strcontains(signalfx_list_chart.avg_duration_by_version.program_text, ".mean(by=['aws_tag_TenantName', 'aws_function_name', 'aws_tag_ForgeModuleRef'])")
    )
    error_message = "Lambda charts and totals must use one-hour invocation, error, and throttle behavior."
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
        strcontains(program_text, "filter('aws_tag_ForgeModuleRef', '*')")
        && strcontains(program_text, "aws_function_name")
        && !strcontains(program_text, "aws_function_version")
        && strcontains(program_text, "filter('Resource', '*')")
        && strcontains(program_text, "not filter('ExecutedVersion', '*')")
      )
    ])
    error_message = "Standard Lambda module charts must use the Forge module reference tag, function name, and canonical resource-level dimensions."
  }

  assert {
    condition = (
      strcontains(signalfx_list_chart.top_tenants_by_errors.program_text, ".sum(by=['aws_tag_TenantName']).sum(over='1h').above(0).top(count=10)")
      && strcontains(signalfx_list_chart.top_tenants_by_throttles.program_text, ".sum(by=['aws_tag_TenantName']).sum(over='1h').above(0).top(count=10)")
      && strcontains(signalfx_list_chart.top_lambdas_by_errors.program_text, ".sum(by=['aws_tag_TenantName', 'aws_function_name', 'aws_tag_ForgeModuleRef']).sum(over='1h').above(0).top(count=10)")
      && strcontains(signalfx_list_chart.top_lambdas_by_throttles.program_text, ".sum(by=['aws_tag_TenantName', 'aws_function_name', 'aws_tag_ForgeModuleRef']).sum(over='1h').above(0).top(count=10)")
    )
    error_message = "Lambda triage charts must rank noisy tenants globally and expose tenant-filtered per-function detail."
  }

  assert {
    condition = (
      one([for option in signalfx_list_chart.percent_invocations_by_version.viz_options : option if option.label == "C"]).display_name == "Invocation share by Forge module"
      && one(signalfx_time_chart.errors_by_version.viz_options).display_name == "Errors"
      && one(signalfx_list_chart.avg_duration_by_version.viz_options).display_name == "Average duration"
      && one(signalfx_time_chart.throttles_by_version.viz_options).display_name == "Throttles"
      && one(signalfx_time_chart.invocations_by_version.viz_options).display_name == "Invocations"
      && one(signalfx_list_chart.top_tenants_by_errors.viz_options).display_name == "Errors"
      && one(signalfx_list_chart.top_tenants_by_throttles.viz_options).display_name == "Throttles"
      && one(signalfx_list_chart.top_lambdas_by_errors.viz_options).display_name == "Errors"
      && one(signalfx_list_chart.top_lambdas_by_throttles.viz_options).display_name == "Throttles"
    )
    error_message = "Lambda plot names must be static metric labels; tenant, function, and Forge module identity belongs in dimension columns."
  }
}

run "lambda_dashboard_wiring_contract" {
  command = plan

  assert {
    condition = (
      signalfx_dashboard.lambda.name == "Forge Tenant - Lambdas"
      && signalfx_dashboard.lambda.dashboard_group == "forge-dashboard-group"
      && length(signalfx_dashboard.lambda.variable[0].values) == 0
      && !signalfx_dashboard.lambda.variable[0].value_required
      && signalfx_dashboard.lambda.variable[0].values_suggested == toset(["tenant-a", "tenant-b"])
      && signalfx_dashboard.lambda.variable[0].restricted_suggestions
      && length(signalfx_dashboard.lambda.chart) == 14
    )
    error_message = "Lambda dashboard must keep its name, group input, and chart count."
  }

  assert {
    condition = alltrue([
      contains([for chart in signalfx_dashboard.lambda.chart : chart.chart_id], signalfx_time_chart.invocations.id),
      contains([for chart in signalfx_dashboard.lambda.chart : chart.chart_id], signalfx_time_chart.invocations_by_version.id),
      contains([for chart in signalfx_dashboard.lambda.chart : chart.chart_id], signalfx_list_chart.percent_invocations_by_version.id),
      contains([for chart in signalfx_dashboard.lambda.chart : chart.chart_id], signalfx_list_chart.top_tenants_by_errors.id),
      contains([for chart in signalfx_dashboard.lambda.chart : chart.chart_id], signalfx_list_chart.top_tenants_by_throttles.id),
      contains([for chart in signalfx_dashboard.lambda.chart : chart.chart_id], signalfx_list_chart.top_lambdas_by_errors.id),
      contains([for chart in signalfx_dashboard.lambda.chart : chart.chart_id], signalfx_list_chart.top_lambdas_by_throttles.id),
    ])
    error_message = "Lambda dashboard must wire summary, tenant ranking, per-function detail, and invocation-share charts."
  }
}
