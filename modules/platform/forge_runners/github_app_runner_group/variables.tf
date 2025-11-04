variable "prefix" {
  description = "Prefix for all resources"
  type        = string
}

variable "tags" {
  description = "Tags to apply to created resources."
  type        = map(string)
  default     = {}
}

variable "secrets_prefix" {
  description = "Prefix for all secrets"
  type        = string
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

variable "github_api" {
  description = "Base URL for the GitHub API (set to GHES API endpoint if using Enterprise)."
  type        = string
  default     = "https://api.github.com"
}

variable "ghes_org" {
  description = "GitHub organization (GHES or GitHub.com)."
  type        = string
}

variable "runner_group_name" {
  description = "Name of the GitHub Actions runner group to create/update and attach repositories to."
  type        = string
}

variable "repository_selection" {
  description = "Repository selection type: 'all' or 'selected'."
  type        = string
  validation {
    condition     = contains(["all", "selected"], var.repository_selection)
    error_message = "repository_selection must be 'all' or 'selected'."
  }
}
