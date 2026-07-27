variable "dashboard_group" {
  description = "Splunk Observability dashboard group ID."
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

variable "tenant_names" {
  description = "Forge tenants available in the dashboard selector."
  type        = list(string)
}

variable "detector_ids" {
  description = "Tenant health detector IDs keyed by tenant for linking dashboard charts."
  type        = map(string)
}
