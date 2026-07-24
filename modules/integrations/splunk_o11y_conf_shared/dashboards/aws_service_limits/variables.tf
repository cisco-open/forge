variable "dynamic_variables" {
  description = "AWS account and Trusted Advisor Region dashboard variable definitions used to scope AWS service-limit metrics."
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
