mock_provider "signalfx" {}

variables {
  tenant_names    = ["tenant-b", "tenant-a"]
  dashboard_group = "forge-dashboard-group"
  detector_ids = {
    tenant-a = "tenant-a-health-detector"
    tenant-b = "tenant-b-health-detector"
  }
  dynamic_variables = [
    {
      property               = "aws_region"
      alias                  = "AWS Region"
      description            = "Limit by AWS region"
      values                 = ["us-east-1"]
      value_required         = true
      values_suggested       = ["us-east-1", "us-west-2"]
      restricted_suggestions = true
    },
    {
      property               = "k8s.cluster.name"
      alias                  = "Kubernetes Cluster"
      description            = "Limit by Kubernetes cluster"
      values                 = []
      value_required         = false
      values_suggested       = ["forge-cluster-a", "forge-cluster-b"]
      restricted_suggestions = true
    }
  ]
}

run "forge_impact_dashboard_contract" {
  command = plan

  assert {
    condition     = terraform_data.dashboard_parent.triggers_replace == "forge-dashboard-group"
    error_message = "Forge impact dashboard must keep its dashboard-group replacement trigger."
  }

  assert {
    condition = (
      strcontains(signalfx_list_chart.top_tenants_lambda_errors.program_text, "data('Errors'")
      && strcontains(signalfx_list_chart.top_tenants_lambda_throttles.program_text, "data('Throttles'")
      && strcontains(signalfx_list_chart.top_tenants_ec2_memory.program_text, "system.memory.usage")
      && strcontains(signalfx_list_chart.top_tenants_ec2_memory.program_text, ".top(count=10)")
      && strcontains(signalfx_list_chart.top_tenants_ec2_memory.program_text, "alerts(detector_id='tenant-a-health-detector')")
      && signalfx_list_chart.top_tenants_ec2_memory.color_by == "Scale"
      && length(signalfx_list_chart.top_tenants_ec2_memory.color_scale) == 3
      && one([for scale in signalfx_list_chart.top_tenants_ec2_memory.color_scale : scale.lt if scale.color == "green"]) == 90
      && strcontains(signalfx_list_chart.top_tenants_ec2_cpu.program_text, "CPUUtilization")
      && signalfx_list_chart.top_tenants_ec2_cpu.color_by == "Scale"
      && length(signalfx_list_chart.top_tenants_ec2_cpu.color_scale) == 3
      && one([for scale in signalfx_list_chart.top_tenants_ec2_cpu.color_scale : scale.lt if scale.color == "green"]) == 90
      && strcontains(signalfx_list_chart.top_tenants_k8s_pending_pods.program_text, "k8s.pod.phase")
      && strcontains(signalfx_list_chart.top_tenants_k8s_failed_pods.program_text, "k8s.pod.phase")
      && strcontains(signalfx_list_chart.top_tenants_sqs_backlog.program_text, "ApproximateNumberOfMessagesVisible")
      && strcontains(signalfx_list_chart.top_tenants_sqs_dlq_backlog.program_text, "*dead-letter*")
      && strcontains(signalfx_list_chart.top_tenants_ec2_disk.program_text, "system.filesystem.usage")
      && strcontains(signalfx_list_chart.top_tenants_ec2_disk.program_text, "filter('type', 'ext4', 'xfs')")
      && strcontains(signalfx_list_chart.top_tenants_ec2_disk.program_text, "filter('mode', 'rw')")
      && strcontains(signalfx_list_chart.top_tenants_ec2_disk.program_text, "alerts(detector_id='tenant-b-health-detector')")
      && strcontains(signalfx_list_chart.top_tenants_ec2_status_failures.program_text, "StatusCheckFailed")
      && strcontains(signalfx_list_chart.top_tenants_k8s_restarts.program_text, "k8s.container.restarts")
      && strcontains(signalfx_list_chart.top_tenants_ebs_queue_length.program_text, "VolumeQueueLength")
      && strcontains(signalfx_list_chart.top_tenants_ebs_iops_exceeded.program_text, "VolumeIOPSExceededCheck")
      && strcontains(signalfx_list_chart.top_tenants_lambda_errors.program_text, "alerts(detector_id='tenant-a-health-detector')")
      && strcontains(signalfx_list_chart.top_tenants_sqs_dlq_backlog.program_text, "tenant-b health alerts")
      && strcontains(signalfx_list_chart.top_tenants_k8s_restarts.program_text, "alerts(detector_id='tenant-a-health-detector')")
      && strcontains(signalfx_list_chart.top_tenants_ec2_status_failures.program_text, "alerts(detector_id='tenant-b-health-detector')")
      && strcontains(signalfx_list_chart.top_tenants_ebs_iops_exceeded.program_text, "alerts(detector_id='tenant-a-health-detector')")
    )
    error_message = "Forge impact must rank affected tenants across live-backed Lambda, EC2, K8S, SQS, and EBS issue signals."
  }

  assert {
    condition = alltrue([
      for program_text in [
        signalfx_list_chart.top_tenants_lambda_errors.program_text,
        signalfx_list_chart.top_tenants_lambda_throttles.program_text,
        signalfx_list_chart.top_tenants_ec2_memory.program_text,
        signalfx_list_chart.top_tenants_ec2_cpu.program_text,
        signalfx_list_chart.top_tenants_ec2_disk.program_text,
        signalfx_list_chart.top_tenants_ec2_status_failures.program_text,
        signalfx_list_chart.top_tenants_sqs_backlog.program_text,
        signalfx_list_chart.top_tenants_sqs_dlq_backlog.program_text,
        signalfx_list_chart.top_tenants_ebs_queue_length.program_text,
        signalfx_list_chart.top_tenants_ebs_iops_exceeded.program_text,
      ] : strcontains(program_text, "filter('aws_tag_TenantName', 'tenant-a') or filter('aws_tag_TenantName', 'tenant-b')")
    ])
    error_message = "AWS issue leaderboards must be restricted to configured Forge tenants."
  }
}

run "forge_impact_dashboard_wiring_contract" {
  command = plan

  assert {
    condition = (
      signalfx_dashboard.forge_impact.name == "Forge Tenant Impact"
      && signalfx_dashboard.forge_impact.dashboard_group == "forge-dashboard-group"
      && length(signalfx_dashboard.forge_impact.chart) == 13
    )
    error_message = "Tenant impact must keep its dashboard identity and pinned chart count."
  }

  assert {
    condition = alltrue([
      contains([for chart in signalfx_dashboard.forge_impact.chart : chart.chart_id], signalfx_list_chart.top_tenants_lambda_errors.id),
      contains([for chart in signalfx_dashboard.forge_impact.chart : chart.chart_id], signalfx_list_chart.top_tenants_ec2_memory.id),
      contains([for chart in signalfx_dashboard.forge_impact.chart : chart.chart_id], signalfx_list_chart.top_tenants_k8s_failed_pods.id),
      contains([for chart in signalfx_dashboard.forge_impact.chart : chart.chart_id], signalfx_list_chart.top_tenants_sqs_dlq_backlog.id),
      contains([for chart in signalfx_dashboard.forge_impact.chart : chart.chart_id], signalfx_list_chart.top_tenants_ec2_status_failures.id),
      contains([for chart in signalfx_dashboard.forge_impact.chart : chart.chart_id], signalfx_list_chart.top_tenants_ebs_queue_length.id),
    ])
    error_message = "Tenant impact must contain its issue leaderboards."
  }
}
