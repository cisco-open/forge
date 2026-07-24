mock_provider "signalfx" {
  mock_resource "signalfx_single_value_chart" {
    defaults = { id = "single-value-chart-id" }
  }
  mock_resource "signalfx_list_chart" {
    defaults = { id = "list-chart-id" }
  }
  mock_resource "signalfx_time_chart" {
    defaults = { id = "time-chart-id" }
  }
  mock_resource "signalfx_dashboard" {}
}

variables {
  dashboard_group = "forge-dashboard-group"
  dynamic_variables = [
    {
      property               = "aws_account_id"
      alias                  = "AWS account"
      description            = ""
      values                 = []
      value_required         = false
      values_suggested       = ["111111111111"]
      restricted_suggestions = true
    },
    {
      property               = "aws_region"
      alias                  = "AWS region"
      description            = ""
      values                 = []
      value_required         = false
      values_suggested       = ["eu-west-1"]
      restricted_suggestions = true
    },
    {
      property               = "aws_tag_ProductFamilyName"
      alias                  = "Product family"
      description            = ""
      values                 = []
      value_required         = false
      values_suggested       = ["Forge MT"]
      restricted_suggestions = true
    },
  ]
}

run "creates_control_plane_s3_dashboard" {
  command = plan

  assert {
    condition = (
      signalfx_dashboard.s3_control_plane.name == "Forge Control Plane - S3"
      && length(signalfx_dashboard.s3_control_plane.chart) == 4
      && length(signalfx_dashboard.s3_control_plane.variable) == 3
    )
    error_message = "The control-plane S3 dashboard must keep its name, four storage panels, and dedicated AWS variables."
  }

  assert {
    condition = alltrue([
      for program_text in [
        signalfx_single_value_chart.active_buckets.program_text,
        signalfx_list_chart.bucket_size.program_text,
        signalfx_list_chart.object_count.program_text,
        signalfx_time_chart.storage_by_class.program_text,
      ] :
      strcontains(program_text, "filter('aws_account_id', '111111111111')")
      && strcontains(program_text, "filter('aws_region', 'eu-west-1')")
      && strcontains(program_text, "filter('aws_tag_ProductFamilyName', 'Forge MT')")
      && strcontains(program_text, "not filter('aws_tag_TenantName', '*')")
      && strcontains(program_text, "filter('namespace', 'AWS/S3')")
    ])
    error_message = "Every control-plane S3 panel must use the AWS scope and exclude tenant-tagged buckets."
  }
}
