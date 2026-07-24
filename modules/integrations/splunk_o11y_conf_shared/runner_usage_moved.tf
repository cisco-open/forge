moved {
  from = module.dashboard_forge_impact.signalfx_list_chart.runner_totals_by_runtime
  to   = module.dashboard_runner_usage.signalfx_list_chart.runner_totals_by_runtime
}

moved {
  from = module.dashboard_forge_impact.signalfx_list_chart.runner_minutes_by_runtime
  to   = module.dashboard_runner_usage.signalfx_list_chart.runner_minutes_by_runtime
}

moved {
  from = module.dashboard_forge_impact.signalfx_time_chart.active_ec2_runners_by_tenant_and_instance_type
  to   = module.dashboard_runner_usage.signalfx_time_chart.active_ec2_runners_by_tenant_and_instance_type
}

moved {
  from = module.dashboard_forge_impact.signalfx_list_chart.active_ec2_runners_by_tenant
  to   = module.dashboard_runner_usage.signalfx_list_chart.active_ec2_runners_by_tenant
}

moved {
  from = module.dashboard_forge_impact.signalfx_list_chart.active_ec2_runners_by_tenant_and_instance_type
  to   = module.dashboard_runner_usage.signalfx_list_chart.active_ec2_runners_by_tenant_and_instance_type
}

moved {
  from = module.dashboard_forge_impact.signalfx_list_chart.total_ec2_runners_by_tenant
  to   = module.dashboard_runner_usage.signalfx_list_chart.total_ec2_runners_by_tenant
}

moved {
  from = module.dashboard_forge_impact.signalfx_list_chart.ec2_runner_hours_by_tenant
  to   = module.dashboard_runner_usage.signalfx_list_chart.ec2_runner_hours_by_tenant
}

moved {
  from = module.dashboard_forge_impact.signalfx_list_chart.ec2_runner_hours_by_tenant_and_instance_type
  to   = module.dashboard_runner_usage.signalfx_list_chart.ec2_runner_hours_by_tenant_and_instance_type
}

moved {
  from = module.dashboard_forge_impact.signalfx_list_chart.k8s_runners_by_tenant
  to   = module.dashboard_runner_usage.signalfx_list_chart.k8s_runners_by_tenant
}

moved {
  from = module.dashboard_forge_impact.signalfx_list_chart.total_k8s_runners_by_tenant
  to   = module.dashboard_runner_usage.signalfx_list_chart.total_k8s_runners_by_tenant
}

moved {
  from = module.dashboard_forge_impact.signalfx_list_chart.k8s_runner_hours_by_tenant
  to   = module.dashboard_runner_usage.signalfx_list_chart.k8s_runner_hours_by_tenant
}

moved {
  from = module.dashboard_forge_impact.terraform_data.runner_usage_dashboard_parent
  to   = module.dashboard_runner_usage.terraform_data.dashboard_parent
}

moved {
  from = module.dashboard_forge_impact.signalfx_dashboard.runner_usage
  to   = module.dashboard_runner_usage.signalfx_dashboard.runner_usage
}
