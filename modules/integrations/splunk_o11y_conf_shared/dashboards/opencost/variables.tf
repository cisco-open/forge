variable "dashboard_group" {
  description = "Dashboard group name for organizing dashboards."
  type        = string
}

variable "tenant_names" {
  description = "Tenant namespaces used to scope OpenCost allocation metrics."
  type        = list(string)
}

variable "dynamic_variables" {
  description = "Additional dynamic variable definitions for deriving dashboard filters."
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
