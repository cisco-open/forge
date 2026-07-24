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

run "ebs_dashboard_contract" {
  command = plan

  assert {
    condition = (
      signalfx_time_chart.byte_utilization_pct.name == "Byte utilization %"
      && signalfx_time_chart.byte_utilization_pct.time_range == 3600
      && strcontains(signalfx_time_chart.byte_utilization_pct.program_text, "EBSByteBalance%")
      && signalfx_time_chart.latency_op.name == "Latency/op (ms)"
      && signalfx_time_chart.latency_op.time_range == 7200
      && !strcontains(signalfx_time_chart.latency_op.program_text, "vol-46dcc55f")
      && strcontains(signalfx_time_chart.latency_op.program_text, ".sum(by=['aws_tag_TenantName', 'aws_region', 'VolumeId'])")
      && signalfx_single_value_chart.state.name == "State"
      && strcontains(signalfx_time_chart.volume_iops_exceeded.program_text, "VolumeIOPSExceededCheck")
      && strcontains(signalfx_time_chart.volume_iops_exceeded.program_text, "filter('aws_tag_TenantName', 'tenant-a') or filter('aws_tag_TenantName', 'tenant-b')")
      && strcontains(signalfx_time_chart.volume_iops_exceeded.program_text, "filter('stat', 'upper')")
    )
    error_message = "EBS charts must keep one-hour utilization visibility, latency, and volume state behavior."
  }
}

run "ebs_dashboard_wiring_contract" {
  command = plan

  assert {
    condition = (
      signalfx_dashboard.ebs.name == "Forge Tenant - EBS"
      && signalfx_dashboard.ebs.dashboard_group == "forge-dashboard-group"
      && signalfx_dashboard.ebs.variable[0].values == toset(["tenant-a", "tenant-b"])
      && signalfx_dashboard.ebs.variable[0].value_required
      && length(signalfx_dashboard.ebs.chart) == 16
    )
    error_message = "EBS dashboard must keep its name, group input, and chart count."
  }

  assert {
    condition = alltrue([
      contains([for chart in signalfx_dashboard.ebs.chart : chart.chart_id], signalfx_single_value_chart.state.id),
      contains([for chart in signalfx_dashboard.ebs.chart : chart.chart_id], signalfx_time_chart.avg_queue_length.id),
      contains([for chart in signalfx_dashboard.ebs.chart : chart.chart_id], signalfx_time_chart.volume_iops_exceeded.id),
    ])
    error_message = "EBS dashboard must keep its first and final chart wiring."
  }
}
