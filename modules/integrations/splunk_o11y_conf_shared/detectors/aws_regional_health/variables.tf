variable "detector_notifications" {
  description = "Detector notification destinations."
  type        = list(string)
}

variable "detector_name_prefix" {
  description = "Prefix to use for Splunk Observability detector names."
  type        = string
}

variable "dynamic_variables" {
  description = "AWS account, region, and product-family definitions used to scope regional platform detectors."
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

variable "team" {
  description = "Splunk Observability team ID."
  type        = string
}
