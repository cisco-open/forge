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
  dashboard_group = "forge-dashboard-group"
  detector_id     = "aws-control-plane-detector"
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

run "creates_lambda_control_plane_dashboard" {
  command = plan

  assert {
    condition = (
      signalfx_dashboard.lambda_control_plane.name == "Forge Control Plane - Lambdas"
      && signalfx_dashboard.lambda_control_plane.dashboard_group == "forge-dashboard-group"
      && length(signalfx_dashboard.lambda_control_plane.chart) == 8
      && length(signalfx_dashboard.lambda_control_plane.variable) == 3
    )
    error_message = "The Lambda control-plane dashboard must keep its name, parent group, seven metric panels, one alert timeline, and dedicated variables."
  }

  assert {
    condition = alltrue([
      for program_text in [
        signalfx_single_value_chart.function_count.program_text,
        signalfx_single_value_chart.total_invocations.program_text,
        signalfx_single_value_chart.total_errors.program_text,
        signalfx_single_value_chart.total_throttles.program_text,
        signalfx_time_chart.invocations_by_function.program_text,
        signalfx_time_chart.errors_and_throttles_by_function.program_text,
        signalfx_time_chart.duration_by_function.program_text,
      ] :
      strcontains(program_text, "filter('aws_account_id', '111111111111')")
      && strcontains(program_text, "filter('aws_account_id', '222222222222')")
      && strcontains(program_text, "filter('aws_region', 'eu-west-1')")
      && strcontains(program_text, "filter('aws_region', 'us-west-2')")
      && strcontains(program_text, "filter('aws_tag_ProductFamilyName', 'Forge MT')")
      && strcontains(program_text, "not filter('aws_tag_TenantName', '*')")
    ])
    error_message = "Every Lambda control-plane panel must be fail-closed and exclude tenant-tagged functions."
  }

  assert {
    condition = (
      !strcontains(signalfx_time_chart.errors_and_throttles_by_function.program_text, "alerts(detector_id=")
      && strcontains(signalfx_time_chart.health_alerts.program_text, "alerts(detector_id='aws-control-plane-detector')")
      && signalfx_time_chart.health_alerts.show_event_lines
    )
    error_message = "Lambda metric charts must remain alert-free and show detector events only on the central timeline."
  }
}
