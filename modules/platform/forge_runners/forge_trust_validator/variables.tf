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

variable "iam_propagation_delay_seconds" {
  type        = number
  description = "Delay between trust policy update and validation to allow IAM/STS propagation."
  default     = 300

  validation {
    condition = (
      var.iam_propagation_delay_seconds >= 0
      && var.iam_propagation_delay_seconds <= 900
    )
    error_message = "iam_propagation_delay_seconds must be between 0 and 900."
  }
}

variable "validation_max_workers" {
  type        = number
  description = "Maximum number of tenant trust relationships validated concurrently for each Forge role."
  default     = 8

  validation {
    condition = (
      var.validation_max_workers >= 1
      && var.validation_max_workers <= 32
    )
    error_message = "validation_max_workers must be between 1 and 32."
  }
}

variable "forge_iam_roles" {
  type        = map(string)
  description = "List of IAM role ARNs for Forge runners."
}

variable "tenant_iam_roles" {
  type        = list(string)
  description = "List of IAM role ARNs that the runners will assume to test trust relationships."
  default     = []
}
