variable "dashboard_group" {
  description = "Dashboard group name for organizing dashboards."
  type        = string
}

variable "tenant_names" {
  description = "Tenant namespaces that run Forge ARC runners."
  type        = list(string)
}
