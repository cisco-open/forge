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

run "creates_sqs_control_plane_dashboard" {
  command = plan

  assert {
    condition = (
      signalfx_dashboard.sqs_control_plane.name == "Forge Control Plane - SQS"
      && signalfx_dashboard.sqs_control_plane.dashboard_group == "forge-dashboard-group"
      && length(signalfx_dashboard.sqs_control_plane.chart) == 7
      && length(signalfx_dashboard.sqs_control_plane.variable) == 3
    )
    error_message = "The SQS control-plane dashboard must keep its name, parent group, seven panels, and dedicated variables."
  }

  assert {
    condition = alltrue([
      for program_text in [
        signalfx_single_value_chart.queue_count.program_text,
        signalfx_time_chart.visible_messages.program_text,
        signalfx_time_chart.oldest_message_age.program_text,
        signalfx_time_chart.messages_by_operation.program_text,
        signalfx_time_chart.messages_by_state.program_text,
        signalfx_time_chart.dlq_visible_messages.program_text,
        signalfx_time_chart.dlq_oldest_message_age.program_text,
      ] :
      strcontains(program_text, "filter('aws_account_id', '111111111111')")
      && strcontains(program_text, "filter('aws_account_id', '222222222222')")
      && strcontains(program_text, "filter('aws_region', 'eu-west-1')")
      && strcontains(program_text, "filter('aws_region', 'us-west-2')")
      && strcontains(program_text, "filter('aws_tag_ProductFamilyName', 'Forge MT')")
      && strcontains(program_text, "not filter('aws_tag_TenantName', '*')")
    ])
    error_message = "Every SQS control-plane panel must be fail-closed and exclude tenant-tagged queues."
  }

  assert {
    condition = (
      strcontains(signalfx_time_chart.dlq_visible_messages.program_text, "*dead_letter*")
      && strcontains(signalfx_time_chart.dlq_visible_messages.program_text, "*dead-letter*")
      && strcontains(signalfx_time_chart.dlq_visible_messages.program_text, "*dlq*")
    )
    error_message = "Control-plane DLQ panels must support Forge dead-letter and DLQ queue naming patterns."
  }

  assert {
    condition = alltrue([
      for program_text in [
        signalfx_time_chart.visible_messages.program_text,
        signalfx_time_chart.oldest_message_age.program_text,
        signalfx_time_chart.dlq_visible_messages.program_text,
      ] : strcontains(program_text, "alerts(detector_id='aws-control-plane-detector')")
    ])
    error_message = "SQS backlog, age, and DLQ charts must show AWS control-plane detector events."
  }
}
