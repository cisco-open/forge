# resource "signalfx_dashboard" "billing" {
#   name            = "Billing"
#   description     = ""
#   dashboard_group = signalfx_dashboard_group.forgecicd.id

#   time_range = "-31d"

#   variable {
#     property         = "forgecicd_tenant"
#     alias            = "ForgeCICD Tenant Name"
#     description      = ""
#     values           = []
#     value_required   = false
#     values_suggested = var.dashboard_variables.runner_k8s.tenant_names
#   }

#   dynamic "variable" {
#     for_each = var.dashboard_variables.billing.dynamic_variables
#     content {
#       property         = each.value.property
#       alias            = each.value.alias
#       description      = each.value.description
#       values           = each.value.values
#       value_required   = each.value.value_required
#       values_suggested = each.value.values_suggested
#     }
#   }


#   # Chart layouts
#   chart {
#     chart_id = signalfx_time_chart.cost_per_service.id
#     width    = 6
#     height   = 1
#     row      = 0
#     column   = 0
#   }

#   chart {
#     chart_id = signalfx_time_chart.net_cost_per_service.id
#     width    = 6
#     height   = 1
#     row      = 0
#     column   = 6
#   }

#   chart {
#     chart_id = signalfx_time_chart.net_cost_per_tenant.id
#     width    = 6
#     height   = 1
#     row      = 1
#     column   = 6
#   }

#   chart {
#     chart_id = signalfx_time_chart.cost_per_tenant.id
#     width    = 6
#     height   = 1
#     row      = 1
#     column   = 0
#   }

#   chart {
#     chart_id = signalfx_time_chart.total_net_cost.id
#     width    = 6
#     height   = 1
#     row      = 2
#     column   = 6
#   }

#   chart {
#     chart_id = signalfx_time_chart.total_cost.id
#     width    = 6
#     height   = 1
#     row      = 2
#     column   = 0
#   }
# }
