variable "dynamic_variables" {
  description = "AWS account, region, and product-family dashboard variable definitions used to scope regional platform health."
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

variable "detector_id" {
  description = "AWS regional platform detector ID linked to queue-health charts."
  type        = string
}
