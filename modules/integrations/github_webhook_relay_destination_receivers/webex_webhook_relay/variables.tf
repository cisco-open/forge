variable "aws_region" {
  description = "Default AWS region."
  type        = string
}

variable "tags" {
  type        = map(string)
  description = "A map of tags to apply to resources."
}

variable "default_tags" {
  type        = map(string)
  description = "A map of tags to apply to resources."
}

variable "logging_retention_in_days" {
  type        = number
  description = "Number of days to retain logs in CloudWatch."
  default     = 3
}

variable "log_level" {
  type        = string
  description = "Log level for application logging (e.g., INFO, DEBUG, WARN, ERROR)"
  default     = "INFO"
}
