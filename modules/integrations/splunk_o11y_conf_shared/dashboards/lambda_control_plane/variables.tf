variable "dynamic_variables" {
  description = "AWS account, region, and product-family dashboard variable definitions used to scope control-plane Lambda metrics."
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
  description = "AWS control-plane detector ID for linking Lambda health alerts."
  type        = string
}

variable "lambda_dimension_filter" {
  description = "Canonical AWS Lambda resource-level SignalFlow filter."
  type        = string
}
