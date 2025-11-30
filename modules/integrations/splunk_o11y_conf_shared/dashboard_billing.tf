resource "signalfx_time_chart" "cost_per_service" {
  name        = "Cost per service"
  description = ""

  program_text = <<-EOF
A = data('forge.per_service.cost_usd')
B = A.max(by=['usage_date', 'service', 'forgecicd_tenant','usage_month', 'usage_year'])
C = B.sum(by=['service', 'forgecicd_tenant','usage_month', 'usage_year'])

# publish both current and baseline
C.publish(label='current')
EOF

  plot_type = "AreaChart"

  axes_precision            = 0
  on_chart_legend_dimension = "service"
  time_range                = 3600

  histogram_options {
    color_theme = "gold"
  }

  viz_options {
    axis         = "left"
    color        = "blue"
    display_name = "current"
    label        = "current"
  }
}

resource "signalfx_time_chart" "net_cost_per_service" {
  name        = "Net Cost per service"
  description = ""

  program_text = <<-EOF
A = data('forge.per_service.net_cost_usd')
B = A.max(by=['usage_date', 'service', 'forgecicd_tenant','usage_month', 'usage_year'])
C = B.sum(by=['service', 'forgecicd_tenant','usage_month', 'usage_year'])  # removes usage_date from label

# publish both current and baseline
C.publish(label='current')
EOF

  plot_type = "AreaChart"

  axes_precision = 0
  time_range     = 3600

  histogram_options {
    color_theme = "gold"
  }

  viz_options {
    axis         = "left"
    color        = "blue"
    display_name = "current"
    label        = "current"
  }
}

resource "signalfx_time_chart" "net_cost_per_tenant" {
  name        = "Net Cost per tenant"
  description = ""

  program_text = <<-EOF
A = data('forge.per_service.net_cost_usd')
B = A.max(by=['usage_date', 'service', 'forgecicd_tenant','usage_month', 'usage_year'])
C = B.sum(by=['forgecicd_tenant','usage_month', 'usage_year'])
D = C.timeshift('29d')

# publish both current and baseline
C.publish(label='current')
#D.publish(label='baseline')
EOF

  plot_type = "AreaChart"

  axes_precision = 0
  time_range     = 3600

  histogram_options {
    color_theme = "gold"
  }

  viz_options {
    axis         = "left"
    color        = "blue"
    display_name = "current"
    label        = "current"
  }
}

resource "signalfx_time_chart" "cost_per_tenant" {
  name        = "Cost per tenant"
  description = ""

  program_text = <<-EOF
A = data('forge.per_service.cost_usd')
B = A.max(by=['usage_date', 'service', 'forgecicd_tenant','usage_month', 'usage_year'])
C = B.sum(by=['forgecicd_tenant','usage_month', 'usage_year'])
D = C.timeshift('29d')

# publish both current and baseline
C.publish(label='current')
#D.publish(label='baseline')
EOF

  plot_type = "AreaChart"

  axes_precision            = 0
  on_chart_legend_dimension = "service"
  time_range                = 3600

  histogram_options {
    color_theme = "gold"
  }

  viz_options {
    axis         = "left"
    color        = "blue"
    display_name = "current"
    label        = "current"
  }
}

resource "signalfx_time_chart" "total_cost" {
  name        = "Total Cost"
  description = ""

  program_text = <<-EOF
A = data('forge.per_service.cost_usd')

# Take max per day/service/tenant, carrying forward last value if missing
B = A.max(by=['usage_date', 'service', 'forgecicd_tenant','usage_month', 'usage_year'])

# Sum by month, still carrying forward where needed
C = B.sum(by=['usage_month', 'usage_year'])

# Shift by 29 days to get a baseline comparison
D = C.timeshift('29d')

# Publish both
C.publish(label='current')
D.publish(label='baseline')
EOF

  plot_type                 = "AreaChart"
  axes_precision            = 0
  on_chart_legend_dimension = "service"


  time_range = 3600
  histogram_options {
    color_theme = "gold"
  }

  viz_options {
    axis         = "left"
    color        = "blue"
    display_name = "current"
    label        = "current"
  }
  viz_options {
    axis         = "left"
    color        = "red"
    display_name = "baseline"
    label        = "baseline"
  }
}

resource "signalfx_time_chart" "total_net_cost" {
  name        = "Total Net Cost"
  description = ""

  program_text = <<-EOF
A = data('forge.per_service.net_cost_usd')

# Take max per day/service/tenant, carrying forward last value if missing
B = A.max(by=['usage_date', 'service', 'forgecicd_tenant','usage_month', 'usage_year'])

# Sum by month, still carrying forward where needed
C = B.sum(by=['usage_month', 'usage_year'])

# Shift by 29 days to get a baseline comparison
D = C.timeshift('29d')

# Publish both
C.publish(label='current')
# D.publish(label='baseline')
EOF

  plot_type      = "AreaChart"
  axes_precision = 0

  time_range = 3600

  histogram_options {
    color_theme = "gold"
  }

  viz_options {
    axis         = "left"
    color        = "blue"
    display_name = "current"
    label        = "current"
  }
}

resource "signalfx_dashboard" "billing" {
  name            = "Billing"
  description     = ""
  dashboard_group = signalfx_dashboard_group.forgecicd.id

  time_range = "-31d"

  variable {
    property               = "forgecicd_tenant"
    alias                  = "ForgeCICD Tenant Name"
    description            = ""
    values                 = []
    value_required         = false
    values_suggested       = var.dashboard_variables.runner_k8s.tenant_names
    restricted_suggestions = true
  }

  dynamic "variable" {
    for_each = var.dashboard_variables.billing.dynamic_variables
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
    chart_id = signalfx_time_chart.cost_per_service.id
    row      = 0
    column   = 0
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.net_cost_per_service.id
    row      = 0
    column   = 6
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.cost_per_tenant.id
    row      = 1
    column   = 0
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.net_cost_per_tenant.id
    row      = 1
    column   = 6
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.total_cost.id
    row      = 2
    column   = 0
    width    = 6
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.total_net_cost.id
    row      = 2
    column   = 6
    width    = 6
    height   = 1
  }
}
