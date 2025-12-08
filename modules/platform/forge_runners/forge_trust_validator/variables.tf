variable "aws_profile" {
  type        = string
  description = "AWS profile (i.e. generated via 'sl aws session generate') to use."
}

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

variable "forge_iam_roles" {
  type        = map(string)
  description = "List of IAM role ARNs for Forge runners."
}

variable "number_forge_iram_roles" {
  type        = number
  description = "Number of Iam roles ARNs for Forge runners"
}

variable "tenant_iam_roles" {
  type        = list(string)
  description = "List of IAM role ARNs that the runners will assume to test trust relationships."
  default     = []
}
