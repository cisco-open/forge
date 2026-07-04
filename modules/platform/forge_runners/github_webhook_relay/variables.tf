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

variable "secret_prefix" {
  description = "Prefix for secret"
  type        = string
}

variable "github_webhook_relay" {
  description = <<-EOT
  Configuration for the optional tenant GitHub webhook relay source.
  If enabled=true, Forge provisions the API Gateway, validation Lambda, source EventBridge bus, and forwarding rule.
  destination_event_bus_name must already exist or be created in the destination account with the destination integration module.
  EOT
  type = object({
    enabled                     = bool
    destination_account_id      = optional(string)
    destination_event_bus_name  = optional(string)
    destination_region          = optional(string)
    destination_reader_role_arn = optional(string)
  })
  default = {
    enabled                     = false
    destination_account_id      = ""
    destination_event_bus_name  = ""
    destination_region          = ""
    destination_reader_role_arn = ""
  }
}
