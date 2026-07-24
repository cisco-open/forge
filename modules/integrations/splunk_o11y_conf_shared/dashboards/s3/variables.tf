variable "tenant_names" {
  description = "Forge tenant names allowed in the dashboard."
  type        = list(string)
}

variable "dynamic_variables" {
  description = "AWS account, region, and product-family dashboard variable definitions used to scope tenant S3 metrics."
  type = list(object({
    property               = string
    alias                  = string
    description            = string
    values                 = list(string)
    value_required         = bool
    values_suggested       = list(string)
    restricted_suggestions = bool
  }))
}

variable "dashboard_group" {
  description = "Splunk Observability dashboard group ID."
  type        = string
}
