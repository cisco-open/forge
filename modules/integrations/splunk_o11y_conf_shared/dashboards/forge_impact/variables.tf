variable "dashboard_group" {
  description = "Dashboard group name for organizing dashboards."
  type        = string
}

variable "dynamic_variables" {
  description = "Additional dynamic variable definitions for the dashboard."
  type = list(object({
    property               = string
    alias                  = string
    description            = string
    values                 = list(string)
    value_required         = bool
    values_suggested       = list(string)
    restricted_suggestions = bool
  }))
  default = []
}

variable "detector_ids" {
  description = "Tenant health detector IDs keyed by tenant for the central alert timeline."
  type        = map(string)
}

variable "tenant_names" {
  description = "Tenant namespaces that run Forge ARC runners."
  type        = list(string)
}
