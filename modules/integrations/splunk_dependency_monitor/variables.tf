variable "aws_profile" {
  type        = string
  description = "AWS profile to use."
}

variable "aws_region" {
  type        = string
  description = "AWS region in which to run the dependency probe."
}

variable "default_tags" {
  type        = map(string)
  description = "A map of default tags to apply to resources."
}

variable "tags" {
  type        = map(string)
  description = "A map of additional tags to apply to resources."
  default     = {}
}

variable "logging_retention_in_days" {
  type        = number
  description = "Number of days to retain dependency-probe Lambda logs."
  default     = 3
}

variable "log_level" {
  type        = string
  description = "Lambda log level."
  default     = "INFO"
}

variable "schedule_expression" {
  type        = string
  description = "EventBridge schedule for tenant dependency probes."
  default     = "cron(*/5 * * * ? *)"
}

variable "github_timeout_seconds" {
  type        = number
  description = "Timeout for each GitHub API request."
  default     = 10
}

variable "github_api_version" {
  type        = string
  description = "GitHub REST API version sent by every regional dependency probe."
  default     = "2022-11-28"
}

variable "splunk_dependency_monitor_config" {
  type = object({
    splunk_hec_url     = string
    splunk_index       = string
    splunk_metrics_url = string
  })
  description = "Splunk Cloud HEC and Splunk Observability metric-ingest configuration."

  validation {
    condition = (
      startswith(var.splunk_dependency_monitor_config.splunk_hec_url, "https://")
      && startswith(var.splunk_dependency_monitor_config.splunk_metrics_url, "https://")
      && endswith(var.splunk_dependency_monitor_config.splunk_metrics_url, "/v2/datapoint")
      && trimspace(var.splunk_dependency_monitor_config.splunk_index) != ""
    )
    error_message = "Splunk URLs must use HTTPS, splunk_metrics_url must end in /v2/datapoint, and splunk_index must not be empty."
  }
}

variable "splunk_http_timeout_seconds" {
  type        = number
  description = "Timeout for batched Splunk Cloud and Splunk O11y HTTP requests."
  default     = 10
}
