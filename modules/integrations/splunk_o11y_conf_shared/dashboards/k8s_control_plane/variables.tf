variable "dynamic_variables" {
  description = "Dashboard variable definitions; only the Kubernetes cluster variable is used."
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

variable "platform_namespaces" {
  description = "Namespaces that contain platform pods required for runner scheduling, networking, and telemetry."
  type        = list(string)
}

variable "dashboard_group" {
  description = "Dashboard group name for organizing dashboards."
  type        = string
}
