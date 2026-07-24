locals {
  configured_tenant_filter = length(var.tenant_names) > 0 ? join(" or ", [
    for tenant_name in sort(var.tenant_names) : "filter('aws_tag_TenantName', '${tenant_name}')"
  ]) : "filter('aws_tag_TenantName', '__forge_tenant_scope_not_configured__')"
  configured_aws_scope_filter = length([
    for variable in var.dynamic_variables : variable
    if variable.value_required && length(variable.values) > 0
    ]) > 0 ? join(" and ", [
    for variable in var.dynamic_variables :
    "filter('${variable.property}', '${join("', '", sort(variable.values))}')"
    if variable.value_required && length(variable.values) > 0
  ]) : "filter('aws_tag_TenantName', '*')"
  ec2_tenant_filter = "(${local.configured_tenant_filter}) and (${local.configured_aws_scope_filter})"

  configured_k8s_tenant_filter = length(var.tenant_names) > 0 ? join(" or ", [
    for namespace in sort(var.tenant_names) : "filter('k8s.namespace.name', '${namespace}')"
  ]) : "filter('k8s.namespace.name', '__forge_tenant_scope_not_configured__')"
  configured_k8s_cluster_filter = length(var.cluster_names) > 0 ? join(" or ", [
    for cluster_name in sort(var.cluster_names) : "filter('k8s.cluster.name', '${cluster_name}')"
  ]) : "filter('k8s.cluster.name', '__forge_cluster_scope_not_configured__')"
  k8s_tenant_namespace_filter = join(" and ", [
    "(${local.configured_k8s_tenant_filter})",
    "(${local.configured_k8s_cluster_filter})",
  ])
}

resource "terraform_data" "dashboard_parent" {
  triggers_replace = var.dashboard_group
}

resource "signalfx_dashboard" "forge_impact" {
  name            = "Forge Tenant Impact"
  description     = "Cross-service tenant issue leaderboards for the first step of workload incident investigation."
  dashboard_group = var.dashboard_group

  # Splunk O11y rejects moving an existing dashboard to a new parent group.
  lifecycle {
    replace_triggered_by = [
      terraform_data.dashboard_parent,
    ]
  }

  chart {
    chart_id = signalfx_list_chart.top_tenants_lambda_errors.id
    row      = 0
    column   = 0
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.top_tenants_lambda_throttles.id
    row      = 0
    column   = 4
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.top_tenants_ec2_memory.id
    row      = 0
    column   = 8
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.top_tenants_ec2_cpu.id
    row      = 1
    column   = 0
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.top_tenants_k8s_pending_pods.id
    row      = 2
    column   = 0
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.top_tenants_k8s_failed_pods.id
    row      = 2
    column   = 4
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.top_tenants_sqs_backlog.id
    row      = 3
    column   = 0
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.top_tenants_sqs_dlq_backlog.id
    row      = 3
    column   = 6
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.top_tenants_ec2_disk.id
    row      = 1
    column   = 4
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.top_tenants_ec2_status_failures.id
    row      = 1
    column   = 8
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.top_tenants_k8s_restarts.id
    row      = 2
    column   = 8
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.top_tenants_ebs_queue_length.id
    row      = 4
    column   = 0
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.top_tenants_ebs_iops_exceeded.id
    row      = 4
    column   = 6
    width    = 6
    height   = 1
  }
}
