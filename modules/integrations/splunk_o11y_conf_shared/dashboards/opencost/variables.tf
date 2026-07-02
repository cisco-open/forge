variable "dashboard_group" {
  description = "Dashboard group name for organizing dashboards."
  type        = string
}

variable "tenant_names" {
  description = "Tenant namespaces used to scope OpenCost allocation metrics."
  type        = list(string)
}
