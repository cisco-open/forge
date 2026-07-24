mock_provider "signalfx" {
  mock_resource "signalfx_time_chart" {
    defaults = {
      id = "time-chart-id"
    }
  }
  mock_resource "signalfx_dashboard" {}
}

variables {
  dashboard_group = "forge-dashboard-group"
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

run "creates_regional_platform_dashboard" {
  command = plan

  assert {
    condition = (
      signalfx_dashboard.aws_regional_health.name == "Forge AWS Regional Platform Health"
      && signalfx_dashboard.aws_regional_health.dashboard_group == "forge-dashboard-group"
      && length(signalfx_dashboard.aws_regional_health.chart) == 5
      && length(signalfx_dashboard.aws_regional_health.variable) == 3
    )
    error_message = "The regional platform dashboard must keep its distinct name, parent group, five live panels, and dedicated variables."
  }

  assert {
    condition = alltrue([
      for program_text in [
        signalfx_time_chart.lambda_throttle_attempt_rate.program_text,
        signalfx_time_chart.lambda_throttle_count.program_text,
        signalfx_time_chart.build_queue_oldest_age.program_text,
        signalfx_time_chart.build_queue_visible_backlog.program_text,
        signalfx_time_chart.build_queue_dlq_sends.program_text,
      ] :
      strcontains(program_text, "filter('aws_account_id', '111111111111')")
      && strcontains(program_text, "filter('aws_account_id', '222222222222')")
      && strcontains(program_text, "filter('aws_region', 'eu-west-1')")
      && strcontains(program_text, "filter('aws_region', 'us-west-2')")
      && strcontains(program_text, "filter('aws_tag_ProductFamilyName', 'Forge MT')")
    ])
    error_message = "Every regional platform panel must be fail-closed to its configured AWS accounts, regions, and product family."
  }

  assert {
    condition = (
      strcontains(signalfx_time_chart.lambda_throttle_attempt_rate.program_text, "data('Throttles'")
      && strcontains(signalfx_time_chart.lambda_throttle_attempt_rate.program_text, "data('Invocations'")
      && strcontains(signalfx_time_chart.lambda_throttle_attempt_rate.program_text, ".scale(100)")
      && strcontains(signalfx_time_chart.build_queue_oldest_age.program_text, "ApproximateAgeOfOldestMessage")
      && strcontains(signalfx_time_chart.build_queue_visible_backlog.program_text, "ApproximateNumberOfMessagesVisible")
      && strcontains(signalfx_time_chart.build_queue_dlq_sends.program_text, "NumberOfMessagesSent")
    )
    error_message = "The managed dashboard must preserve the five live regional Lambda and queued-build signals."
  }
}
