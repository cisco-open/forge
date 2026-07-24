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

run "forge_impact_dashboard_contract" {
  command = plan

  assert {
    condition = (
      terraform_data.dashboard_parent.triggers_replace == "forge-dashboard-group"
    )
    error_message = "Forge impact dashboard must keep the dashboard-group replacement trigger."
  }

  assert {
    condition = (
      signalfx_list_chart.runner_totals_by_runtime.name == "Total runners by runtime over selected window"
      && strcontains(signalfx_list_chart.runner_totals_by_runtime.program_text, "CPUUtilization")
      && strcontains(signalfx_list_chart.runner_totals_by_runtime.program_text, "filter('aws_tag_TenantName', 'tenant-a') or filter('aws_tag_TenantName', 'tenant-b')")
      && strcontains(signalfx_list_chart.runner_totals_by_runtime.program_text, "filter('k8s.namespace.name', 'tenant-a') or filter('k8s.namespace.name', 'tenant-b')")
      && signalfx_list_chart.active_ec2_runners_by_tenant.name == "Active EC2 runners by tenant"
      && strcontains(signalfx_list_chart.k8s_runners_by_tenant.program_text, "container.memory.usage")
    )
    error_message = "Forge impact charts must keep EC2 and K8S runner adoption SignalFlow behavior."
  }

  assert {
    condition = (
      strcontains(signalfx_list_chart.top_tenants_lambda_errors.program_text, "data('Errors'")
      && strcontains(signalfx_list_chart.top_tenants_lambda_throttles.program_text, "data('Throttles'")
      && strcontains(signalfx_list_chart.top_tenants_ec2_memory.program_text, "system.memory.usage")
      && strcontains(signalfx_list_chart.top_tenants_ec2_memory.program_text, ".top(count=10)")
      && signalfx_list_chart.top_tenants_ec2_memory.color_by == "Scale"
      && strcontains(signalfx_list_chart.top_tenants_ec2_cpu.program_text, "CPUUtilization")
      && signalfx_list_chart.top_tenants_ec2_cpu.color_by == "Scale"
      && strcontains(signalfx_list_chart.top_tenants_k8s_pending_pods.program_text, "k8s.pod.phase")
      && strcontains(signalfx_list_chart.top_tenants_k8s_failed_pods.program_text, "k8s.pod.phase")
      && strcontains(signalfx_list_chart.top_tenants_sqs_backlog.program_text, "ApproximateNumberOfMessagesVisible")
      && strcontains(signalfx_list_chart.top_tenants_sqs_dlq_backlog.program_text, "*dead-letter*")
      && strcontains(signalfx_list_chart.top_tenants_dynamodb_throttles.program_text, "ThrottledRequests")
      && strcontains(signalfx_list_chart.top_tenants_dynamodb_system_errors.program_text, "SystemErrors")
      && strcontains(signalfx_list_chart.top_tenants_ebs_queue_length.program_text, "VolumeQueueLength")
    )
    error_message = "Forge impact must rank affected tenants across Lambda, EC2, K8S, SQS, DynamoDB, and EBS issue signals."
  }

  assert {
    condition = alltrue([
      for program_text in [
        signalfx_list_chart.top_tenants_lambda_errors.program_text,
        signalfx_list_chart.top_tenants_lambda_throttles.program_text,
        signalfx_list_chart.top_tenants_ec2_memory.program_text,
        signalfx_list_chart.top_tenants_ec2_cpu.program_text,
        signalfx_list_chart.top_tenants_sqs_backlog.program_text,
        signalfx_list_chart.top_tenants_sqs_dlq_backlog.program_text,
        signalfx_list_chart.top_tenants_dynamodb_throttles.program_text,
        signalfx_list_chart.top_tenants_dynamodb_system_errors.program_text,
        signalfx_list_chart.top_tenants_ebs_queue_length.program_text,
      ] : strcontains(program_text, "filter('aws_tag_TenantName', 'tenant-a') or filter('aws_tag_TenantName', 'tenant-b')")
    ])
    error_message = "AWS issue leaderboards must be restricted to configured Forge tenants."
  }
}

run "forge_impact_dashboard_wiring_contract" {
  command = plan

  assert {
    condition = (
      signalfx_dashboard.forge_impact.name == "ForgeCICD Impact"
      && signalfx_dashboard.forge_impact.dashboard_group == "forge-dashboard-group"
      && length(signalfx_dashboard.forge_impact.chart) == 22
    )
    error_message = "Forge impact dashboard must keep its name, group input, and chart count."
  }

  assert {
    condition = alltrue([
      contains([for chart in signalfx_dashboard.forge_impact.chart : chart.chart_id], signalfx_list_chart.active_ec2_runners_by_tenant.id),
      contains([for chart in signalfx_dashboard.forge_impact.chart : chart.chart_id], signalfx_list_chart.ec2_runner_hours_by_tenant_and_instance_type.id),
      contains([for chart in signalfx_dashboard.forge_impact.chart : chart.chart_id], signalfx_list_chart.top_tenants_lambda_errors.id),
      contains([for chart in signalfx_dashboard.forge_impact.chart : chart.chart_id], signalfx_list_chart.top_tenants_ec2_memory.id),
      contains([for chart in signalfx_dashboard.forge_impact.chart : chart.chart_id], signalfx_list_chart.top_tenants_k8s_failed_pods.id),
      contains([for chart in signalfx_dashboard.forge_impact.chart : chart.chart_id], signalfx_list_chart.top_tenants_sqs_dlq_backlog.id),
      contains([for chart in signalfx_dashboard.forge_impact.chart : chart.chart_id], signalfx_list_chart.top_tenants_dynamodb_throttles.id),
      contains([for chart in signalfx_dashboard.forge_impact.chart : chart.chart_id], signalfx_list_chart.top_tenants_ebs_queue_length.id),
    ])
    error_message = "Forge impact dashboard must wire cross-service issue leaderboards and retain adoption charts."
  }
}
