
variable "tenant_names" {
  description = "List of tenant names used for the dashboard."
  type        = list(string)
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

variable "dashboard_group" {
  description = "Dashboard group name for organizing dashboards."
  type        = string
}
