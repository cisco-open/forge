variable "token_ids" {
  description = "Splunk Observability ingest token IDs owned by Forge. These are identifiers, not token secrets. An empty list makes every token-scoped chart fail closed."
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

variable "ingest_sources" {
  description = "Stable forgecicd_ingest_source dimension values emitted by Forge metric senders. An empty list makes the retained-metric inventory chart fail closed."
  type        = list(string)
  default     = []

  validation {
    condition = (
      length(distinct(var.ingest_sources)) == length(var.ingest_sources)
      && alltrue([
        for ingest_source in var.ingest_sources : can(regex("^[A-Za-z0-9_-]+$", ingest_source))
      ])
    )
    error_message = "ingest_sources must contain distinct source IDs made only of letters, numbers, underscores, or hyphens."
  }
}

variable "dashboard_group" {
  description = "Splunk Observability dashboard group ID."
  type        = string
}
