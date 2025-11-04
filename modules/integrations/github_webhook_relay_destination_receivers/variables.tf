variable "aws_profile" {
  description = "AWS profile (i.e., generated via 'sl aws session generate') to use."
  type        = string
}

variable "aws_region" {
  description = "Default AWS region."
  type        = string
}

variable "default_tags" {
  type        = map(string)
  description = "A map of tags to apply to resources."

}
variable "tags" {
  type        = map(string)
  description = "A map of tags to apply to resources."
}

variable "reader_config" {
  description = "Configuration for the reader to fetch secrets."
  type = object({
    enable_secret_fetch    = bool
    source_secret_role_arn = string
    source_secret_arn      = string
    source_secret_region   = string
  })
}

variable "webhook_relay_destination_config" {
  description = "Configuration for webhook relay destination."
  type = object({
    name_prefix                = string
    destination_event_bus_name = string
    source_account_id          = string
  })
}

variable "logging_retention_in_days" {
  description = "Number of days to retain logs."
  type        = number
  default     = 3
}

variable "log_level" {
  type        = string
  description = "Log level for application logging (e.g., INFO, DEBUG, WARN, ERROR)"
  default     = "INFO"
}

variable "enable_webex_webhook_relay" {
  type        = bool
  description = "Enable Webex webhook relay."
}
