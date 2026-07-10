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
      && strcontains(signalfx_list_chart.runner_totals_by_runtime.program_text, "filter('k8s.namespace.name', 'tenant-a') or filter('k8s.namespace.name', 'tenant-b')")
      && signalfx_list_chart.active_ec2_runners_by_tenant.name == "Active EC2 runners by tenant"
      && strcontains(signalfx_list_chart.k8s_runners_by_tenant.program_text, "container.memory.usage")
    )
    error_message = "Forge impact charts must keep EC2 and K8S runner adoption SignalFlow behavior."
  }
}

run "forge_impact_dashboard_wiring_contract" {
  command = plan

  assert {
    condition = (
      signalfx_dashboard.forge_impact.name == "ForgeCICD Impact"
      && signalfx_dashboard.forge_impact.dashboard_group == "forge-dashboard-group"
      && length(signalfx_dashboard.forge_impact.chart) == 11
    )
    error_message = "Forge impact dashboard must keep its name, group input, and chart count."
  }

  assert {
    condition = alltrue([
      contains([for chart in signalfx_dashboard.forge_impact.chart : chart.chart_id], signalfx_list_chart.active_ec2_runners_by_tenant.id),
      contains([for chart in signalfx_dashboard.forge_impact.chart : chart.chart_id], signalfx_list_chart.ec2_runner_hours_by_tenant_and_instance_type.id),
    ])
    error_message = "Forge impact dashboard must keep its first and final chart wiring."
  }
}
