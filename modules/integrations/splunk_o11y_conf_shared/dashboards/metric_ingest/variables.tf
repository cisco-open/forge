variable "token_ids" {
  description = "Splunk Observability ingest token IDs owned by Forge. These are identifiers, not token secrets. An empty list makes every chart fail closed."
  type        = list(string)

  validation {
    condition = (
      length(distinct(var.token_ids)) == length(var.token_ids)
      && alltrue([
        for token_id in var.token_ids : can(regex("^[A-Za-z0-9_-]+$", token_id))
      ])
    )
    error_message = "token_ids must contain distinct Splunk token IDs made only of letters, numbers, underscores, or hyphens."
  }
}

variable "dashboard_group" {
  description = "Splunk Observability dashboard group ID."
  type        = string
}
