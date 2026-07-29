variable "dashboard_group" {
  description = "Splunk Observability dashboard group ID."
  type        = string
}

variable "tenant_names" {
  description = "Forge tenant namespaces available in the ARC dashboard selector and metric scope."
  type        = list(string)
}

variable "dynamic_variables" {
  description = "Cluster and environment variables applied to the ARC dashboard."
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
