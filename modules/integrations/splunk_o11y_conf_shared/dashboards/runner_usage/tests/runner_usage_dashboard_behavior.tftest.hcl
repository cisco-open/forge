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
    },
    {
      property               = "k8s.cluster.name"
      alias                  = "Kubernetes cluster"
      description            = "Limit by Kubernetes cluster"
      values                 = []
      value_required         = false
      values_suggested       = ["forge-cluster-b", "forge-cluster-a"]
      restricted_suggestions = true
    }
  ]
}

run "runner_usage_dashboard_contract" {
  command = plan

  assert {
    condition     = terraform_data.dashboard_parent.triggers_replace == "forge-dashboard-group"
    error_message = "Runner usage dashboard must keep its dashboard-group replacement trigger."
  }

  assert {
    condition = (
      signalfx_list_chart.runner_totals_by_runtime.name == "Total runners by runtime over selected window"
      && strcontains(signalfx_list_chart.runner_totals_by_runtime.program_text, "CPUUtilization")
      && strcontains(signalfx_list_chart.runner_totals_by_runtime.program_text, "filter('aws_tag_TenantName', 'tenant-a') or filter('aws_tag_TenantName', 'tenant-b')")
      && strcontains(signalfx_list_chart.runner_totals_by_runtime.program_text, "filter('aws_region', 'us-east-1')")
      && strcontains(signalfx_list_chart.runner_totals_by_runtime.program_text, "filter('k8s.namespace.name', 'tenant-a') or filter('k8s.namespace.name', 'tenant-b')")
      && strcontains(signalfx_list_chart.runner_totals_by_runtime.program_text, "filter('k8s.cluster.name', 'forge-cluster-a') or filter('k8s.cluster.name', 'forge-cluster-b')")
      && signalfx_list_chart.active_ec2_runners_by_tenant.name == "Active EC2 runners by tenant"
      && strcontains(signalfx_list_chart.k8s_runners_by_tenant.program_text, "container.memory.usage")
    )
    error_message = "Runner usage charts must keep EC2 and K8S adoption SignalFlow behavior."
  }

  assert {
    condition = (
      signalfx_dashboard.runner_usage.name == "Forge Runner Usage"
      && signalfx_dashboard.runner_usage.dashboard_group == "forge-dashboard-group"
      && length(signalfx_dashboard.runner_usage.chart) == 11
      && contains([for chart in signalfx_dashboard.runner_usage.chart : chart.chart_id], signalfx_list_chart.active_ec2_runners_by_tenant.id)
      && contains([for chart in signalfx_dashboard.runner_usage.chart : chart.chart_id], signalfx_list_chart.ec2_runner_hours_by_tenant_and_instance_type.id)
    )
    error_message = "Runner usage must keep its dashboard identity and adoption charts."
  }
}
