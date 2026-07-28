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
  configured_k8s_cluster_names = distinct(flatten([
    for var_def in var.dynamic_variables : var_def.values_suggested
    if var_def.property == "k8s.cluster.name"
  ]))
  configured_k8s_cluster_filter = length(local.configured_k8s_cluster_names) > 0 ? join(" or ", [
    for cluster_name in local.configured_k8s_cluster_names : "filter('k8s.cluster.name', '${cluster_name}')"
  ]) : "filter('k8s.cluster.name', '__forge_cluster_scope_not_configured__')"
  k8s_tenant_namespace_filter = join(" and ", [
    "(${local.configured_k8s_tenant_filter})",
    "(${local.configured_k8s_cluster_filter})",
  ])
  tenant_health_alerts = join("\n", [
    for tenant_name, detector_id in var.detector_ids :
    "alerts(detector_id='${detector_id}').publish(label='${tenant_name} health alerts')"
  ])
}

resource "terraform_data" "dashboard_parent" {
  triggers_replace = var.dashboard_group
}

resource "signalfx_time_chart" "tenant_health_alerts" {
  name        = "Tenant health alerts"
  description = "Central alert timeline for the per-tenant health detectors. Issue leaderboards remain metric-only so unrelated alerts do not appear on every chart."

  program_text = local.tenant_health_alerts

  plot_type        = "LineChart"
  show_event_lines = true
  time_range       = 3600
}

resource "signalfx_text_chart" "operator_guide" {
  name        = "How should I use this dashboard?"
  description = "Operator workflow for tenant-impact triage."

  markdown = <<-EOF
## How should I use this dashboard?

1. **Start with active alerts:** record the tenant, affected signal, alert start time, and incident window.
2. **Find the blast radius:** compare the leaderboards across Lambda, EC2, Kubernetes, SQS, and EBS. One elevated metric is a lead for investigation, not a confirmed failure.
3. **Scope the workload:** select the tenant, AWS region, or Kubernetes cluster and capture the repository, workflow-job ID, runner labels, and expected runner model from the affected run.
4. **Follow the real path:** check webhook and dispatcher evidence, then SQS or redelivery, then EC2 provisioning or ARC listener and capacity, and finally runner registration and job progress.
5. **Assign ownership from evidence:** cross-tenant patterns suggest the Forge shared platform; one tenant may indicate tenant IaC or workload pressure; provider or API failures belong to the external dependency boundary.
6. **Validate recovery:** confirm the detector clears and the affected workflow completes. A retry succeeding without a Forge change is transient evidence, not a root cause.

Use service dashboards for diagnosis and production logs for exact job, delivery, message, request, runner, pod, or node identifiers.
EOF
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
    chart_id = signalfx_text_chart.operator_guide.id
    row      = 0
    column   = 0
    width    = 12
    height   = 2
  }

  chart {
    chart_id = signalfx_time_chart.tenant_health_alerts.id
    row      = 2
    column   = 0
    width    = 12
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.top_tenants_lambda_errors.id
    row      = 3
    column   = 0
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.top_tenants_lambda_throttles.id
    row      = 3
    column   = 4
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.top_tenants_ec2_memory.id
    row      = 3
    column   = 8
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.top_tenants_ec2_cpu.id
    row      = 4
    column   = 0
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.top_tenants_ec2_disk.id
    row      = 4
    column   = 4
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.top_tenants_ec2_status_failures.id
    row      = 4
    column   = 8
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.top_tenants_k8s_pending_pods.id
    row      = 5
    column   = 0
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.top_tenants_k8s_failed_pods.id
    row      = 5
    column   = 4
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.top_tenants_k8s_restarts.id
    row      = 5
    column   = 8
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.top_tenants_sqs_backlog.id
    row      = 6
    column   = 0
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.top_tenants_sqs_dlq_backlog.id
    row      = 6
    column   = 6
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.top_tenants_ebs_queue_length.id
    row      = 7
    column   = 0
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.top_tenants_ebs_iops_exceeded.id
    row      = 7
    column   = 6
    width    = 6
    height   = 1
  }
}
