variable "detector_notifications" {
  description = "Detector notification destinations."
  type        = list(string)
}

variable "detector_name_prefix" {
  description = "Prefix to use for Splunk Observability detector names."
  type        = string
}

variable "dynamic_variables" {
  description = "Dynamic metric property definitions used to scope the EC2 runner detectors."
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

variable "resource_pressure_notifications" {
  description = "Optional notification override for the standalone disk and memory pressure detectors."
  type        = list(string)
  default     = null
}

variable "tenant_names" {
  description = "Forge tenant names allowed to contribute runner health signals."
  type        = list(string)
}
