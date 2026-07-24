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

run "creates_kinesis_control_plane_dashboard" {
  command = plan

  assert {
    condition = (
      signalfx_dashboard.kinesis_control_plane.name == "Forge Control Plane - Kinesis"
      && signalfx_dashboard.kinesis_control_plane.dashboard_group == "forge-dashboard-group"
      && length(signalfx_dashboard.kinesis_control_plane.chart) == 8
      && length(signalfx_dashboard.kinesis_control_plane.variable) == 3
    )
    error_message = "The Kinesis control-plane dashboard must keep its name, parent group, eight panels, and dedicated variables."
  }

  assert {
    condition = alltrue([
      for program_text in [
        signalfx_single_value_chart.stream_count.program_text,
        signalfx_time_chart.incoming_records.program_text,
        signalfx_time_chart.incoming_bytes.program_text,
        signalfx_time_chart.throughput_exceeded.program_text,
        signalfx_time_chart.iterator_age.program_text,
        signalfx_time_chart.successful_operations.program_text,
        signalfx_time_chart.get_records_latency.program_text,
        signalfx_time_chart.put_records_latency.program_text,
      ] :
      strcontains(program_text, "filter('aws_account_id', '111111111111')")
      && strcontains(program_text, "filter('aws_account_id', '222222222222')")
      && strcontains(program_text, "filter('aws_region', 'eu-west-1')")
      && strcontains(program_text, "filter('aws_region', 'us-west-2')")
      && strcontains(program_text, "filter('aws_tag_ProductFamilyName', 'Forge MT')")
      && strcontains(program_text, "not filter('aws_tag_TenantName', '*')")
      && strcontains(program_text, "filter('namespace', 'AWS/Kinesis')")
      && strcontains(program_text, "filter('StreamName', '*')")
    ])
    error_message = "Every Kinesis control-plane panel must be fail-closed and exclude tenant-tagged streams."
  }

  assert {
    condition = (
      strcontains(signalfx_time_chart.throughput_exceeded.program_text, "ReadProvisionedThroughputExceeded")
      && strcontains(signalfx_time_chart.throughput_exceeded.program_text, "WriteProvisionedThroughputExceeded")
      && strcontains(signalfx_time_chart.iterator_age.program_text, "GetRecords.IteratorAgeMilliseconds")
      && strcontains(signalfx_time_chart.successful_operations.program_text, "GetRecords.Success")
      && strcontains(signalfx_time_chart.successful_operations.program_text, "PutRecords.Success")
    )
    error_message = "The dashboard must preserve the Kinesis throttling, consumer-lag, and successful-operation signals from the AWS example."
  }
}
