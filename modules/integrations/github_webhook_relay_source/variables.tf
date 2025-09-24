variable "name_prefix" {
  description = "Prefix for created resources"
  type        = string
  default     = "webhook-relay-source"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "webhook_secret" {
  description = "Secret used to validate incoming webhooks"
  type        = string
}

variable "event_source" {
  description = "EventBridge source field for emitted events"
  type        = string
  default     = "webhook.relay"
}

variable "source_event_bus_name" {
  description = "Name of the source EventBridge bus"
  type        = string
  default     = "webhook-relay-source"
}

variable "destination_account_id" {
  description = "Destination (receiver) AWS account ID"
  type        = string
}

variable "destination_region" {
  description = "Destination region (omit for same as source)"
  type        = string
  default     = null
}

variable "destination_event_bus_name" {
  description = "Destination bus name in destination account"
  type        = string
}

variable "log_retention_in_days" {
  description = "Log retention period in days"
  type        = number
  default     = 3
}
