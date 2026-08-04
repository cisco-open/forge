variable "shared_role_arns" {
  description = "Optional list of consumer identifier to IAM Role ARN granted read/list on tenant's github job logs."
  type        = list(string)
  default     = []
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

variable "tags" {
  description = "Tags to apply to created resources."
  type        = map(string)
  default     = {}
}

variable "event_bus_name" {
  type        = string
  description = "Name of the EventBridge event bus to listen for workflow job events."
}

variable "ghes_url" {
  description = "GitHub Enterprise Server URL."
  type        = string
  default     = ""
}

variable "prefix" {
  description = "Prefix for all resources"
  type        = string
}

variable "github_app" {
  description = "GitHub App configuration"
  type = object({
    key_base64_ssm = object({
      arn = string
    })
    id_ssm = object({
      arn = string
    })
    installation_id_ssm = object({
      arn = string
    })
  })
}
