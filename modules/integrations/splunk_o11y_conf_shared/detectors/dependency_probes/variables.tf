variable "detector_notifications" {
  description = "Detector notification destinations."
  type        = list(string)
}

variable "detector_name_prefix" {
  description = "Prefix to use for Splunk Observability detector names."
  type        = string
}

variable "team" {
  description = "Splunk Observability team ID."
  type        = string
}

variable "tenant_names" {
  description = "Forge tenants that require independent dependency detectors."
  type        = list(string)
}

variable "detector_config" {
  description = "Thresholds and durations for tenant dependency detectors."
  type = object({
    failure_duration                   = string
    no_data_duration                   = string
    no_data_fill_duration              = string
    rate_limit_duration                = string
    rate_limit_remaining_pct_threshold = number
  })
}
