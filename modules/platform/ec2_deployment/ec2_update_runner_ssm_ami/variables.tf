variable "prefix" {
  description = "Prefix for all resources"
  type        = string
}

variable "tags" {
  description = "Tags to apply to created resources."
  type        = map(string)
  default     = {}
}

variable "logging_retention_in_days" {
  description = "Retention in days for CloudWatch Log Group for the Lambdas."
  type        = number
  default     = 30
}

variable "log_level" {
  type        = string
  description = "Log level for application logging (e.g., INFO, DEBUG, WARN, ERROR)"
  default     = "INFO"
}

variable "runner_ami_map" {
  type = map(object({
    resource_ssm_id = string
    ssm_id          = string
    ami_filter = object({
      name  = list(string)
      state = list(string)
    })
    ami_owners = list(string)
  }))
}
