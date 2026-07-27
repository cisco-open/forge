locals {
  tenant_filter = length(var.tenant_names) > 0 ? join(" or ", [
    for tenant_name in sort(var.tenant_names) :
    "filter('TenantName', '${tenant_name}')"
  ]) : "filter('TenantName', '__forge_tenant_scope_not_configured__')"
  metric_filter = "(${local.tenant_filter})"
  detector_alerts = join("\n", [
    for tenant_name, detector_id in var.detector_ids :
    "alerts(detector_id='${detector_id}').publish(label='${tenant_name} health alerts')"
  ])
}

resource "signalfx_list_chart" "github_availability" {
  name                    = "GitHub checks by tenant"
  description             = "Latest GitHub authentication and organization runner API availability. Zero indicates a failed check."
  color_by                = "Scale"
  hide_missing_values     = false
  max_precision           = 0
  secondary_visualization = "Sparkline"
  sort_by                 = "+value"
  time_range              = 3600
  unit_prefix             = "Metric"

  program_text = <<-EOF
A = data('forge.dependency.availability', filter=(${local.metric_filter}) and filter('Provider', 'GitHub'), rollup='latest').min(by=['TenantName', 'AWSRegion', 'CheckName']).publish(label='A')
EOF

  color_scale {
    color = "red"
    lt    = 1
  }
  color_scale {
    color = "green"
    gte   = 1
  }

  legend_options_fields {
    enabled  = true
    property = "TenantName"
  }
  legend_options_fields {
    enabled  = true
    property = "CheckName"
  }

  viz_options {
    display_name = "GitHub availability"
    label        = "A"
  }
}

resource "signalfx_list_chart" "ssm_availability" {
  name                    = "AWS SSM access by tenant"
  description             = "Latest regional access result for the tenant GitHub App and routing parameters."
  color_by                = "Scale"
  hide_missing_values     = false
  max_precision           = 0
  secondary_visualization = "Sparkline"
  sort_by                 = "+value"
  time_range              = 3600
  unit_prefix             = "Metric"

  program_text = <<-EOF
A = data('forge.dependency.availability', filter=(${local.metric_filter}) and filter('Provider', 'AWS') and filter('CheckName', 'SSMCredentials'), rollup='latest').min(by=['TenantName', 'AWSRegion']).publish(label='A')
EOF

  color_scale {
    color = "red"
    lt    = 1
  }
  color_scale {
    color = "green"
    gte   = 1
  }

  legend_options_fields {
    enabled  = true
    property = "TenantName"
  }

  viz_options {
    display_name = "SSM availability"
    label        = "A"
  }
}

resource "signalfx_list_chart" "rate_limit_budget" {
  name                    = "GitHub API rate-limit budget"
  description             = "Latest percentage of the installation token's GitHub API rate-limit budget remaining."
  color_by                = "Scale"
  hide_missing_values     = false
  max_precision           = 2
  secondary_visualization = "Sparkline"
  sort_by                 = "+value"
  time_range              = 3600
  unit_prefix             = "Metric"

  program_text = <<-EOF
A = data('forge.dependency.rate_limit_remaining_pct', filter=(${local.metric_filter}) and filter('Provider', 'GitHub') and filter('CheckName', 'OrgRunnersApi'), rollup='latest').min(by=['TenantName', 'AWSRegion']).publish(label='A')
EOF

  color_scale {
    color = "red"
    lt    = 10
  }
  color_scale {
    color = "orange"
    gte   = 10
    lt    = 25
  }
  color_scale {
    color = "green"
    gte   = 25
  }

  legend_options_fields {
    enabled  = true
    property = "TenantName"
  }

  viz_options {
    display_name = "Rate-limit remaining"
    label        = "A"
    value_suffix = "%"
  }
}

resource "signalfx_time_chart" "latency" {
  name        = "Dependency check latency"
  description = "SSM, GitHub App authentication, and organization runner API latency by tenant and region."

  program_text = "A = data('forge.dependency.latency_ms', filter=(${local.metric_filter}), rollup='average').mean(by=['TenantName', 'AWSRegion', 'Provider', 'CheckName']).publish(label='A')"

  plot_type        = "LineChart"
  show_event_lines = false
  time_range       = 3600
  unit_prefix      = "Metric"

  axis_left {
    label = "Milliseconds"
  }

  legend_options_fields {
    enabled  = true
    property = "TenantName"
  }
  legend_options_fields {
    enabled  = true
    property = "Provider"
  }
  legend_options_fields {
    enabled  = true
    property = "CheckName"
  }

  viz_options {
    display_name = "Latency"
    label        = "A"
    value_unit   = "Millisecond"
  }
}

resource "signalfx_time_chart" "probe_execution" {
  name        = "Regional probe execution"
  description = "Scheduled dependency-probe executions by tenant and AWS region. Missing series indicate absent telemetry."

  program_text = <<-EOF
A = data('forge.dependency.probe_executed', filter=(${local.metric_filter}) and filter('Provider', 'Forge') and filter('CheckName', 'TenantCycle'), rollup='sum').sum(by=['TenantName', 'AWSRegion']).publish(label='A')
EOF

  plot_type        = "ColumnChart"
  show_event_lines = false
  time_range       = 3600
  unit_prefix      = "Metric"

  legend_options_fields {
    enabled  = true
    property = "TenantName"
  }

  viz_options {
    display_name = "Probe executions"
    label        = "A"
  }
}

resource "terraform_data" "dashboard_parent" {
  triggers_replace = var.dashboard_group
}

resource "signalfx_time_chart" "tenant_health_alerts" {
  name        = "Tenant health alerts"
  description = "Central alert timeline for the per-tenant dependency-health detectors. Dependency metric charts remain alert-free for clear correlation."

  program_text = local.detector_alerts

  plot_type        = "LineChart"
  show_event_lines = true
  time_range       = 3600
}

resource "signalfx_dashboard" "dependency_health" {
  name            = "Forge External Dependency Health"
  description     = "Tenant-level GitHub and AWS dependency availability, latency, rate-limit budget, and regional probe telemetry."
  dashboard_group = var.dashboard_group
  time_range      = "-1h"

  lifecycle {
    replace_triggered_by = [
      terraform_data.dashboard_parent,
    ]
  }

  variable {
    property               = "aws_tag_TenantName"
    alias                  = "ForgeCICD Tenant Name"
    description            = ""
    values                 = []
    value_required         = false
    values_suggested       = sort(var.tenant_names)
    restricted_suggestions = true
  }

  dynamic "variable" {
    for_each = var.dynamic_variables
    iterator = var_def

    content {
      property               = var_def.value.property
      alias                  = var_def.value.alias
      description            = var_def.value.description
      values                 = var_def.value.values
      value_required         = var_def.value.value_required
      values_suggested       = var_def.value.values_suggested
      restricted_suggestions = var_def.value.restricted_suggestions
    }
  }

  chart {
    chart_id = signalfx_list_chart.github_availability.id
    row      = 0
    column   = 0
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.ssm_availability.id
    row      = 0
    column   = 4
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.rate_limit_budget.id
    row      = 0
    column   = 8
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.latency.id
    row      = 1
    column   = 0
    width    = 12
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.probe_execution.id
    row      = 2
    column   = 0
    width    = 12
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.tenant_health_alerts.id
    row      = 3
    column   = 0
    width    = 12
    height   = 1
  }
}
