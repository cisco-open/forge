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

variable "log_retention_days" {
  type        = number
  description = "Number of days to retain logs in CloudWatch."
  default     = 3
}
