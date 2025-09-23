variable "name_prefix" {
  description = "Prefix for destination resources"
  type        = string
  default     = "webhook-relay-destination"
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}

variable "destination_event_bus_name" {
  description = "Destination bus name"
  type        = string
  default     = "webhook-relay-destination"
}

variable "source_account_id" {
  description = "Source account allowed to PutEvents"
  type        = string
}

variable "targets" {
  description = <<EOT
List of targets. Each object = { event_pattern = JSON string, lambda_function_name = string }.
If empty, legacy event_pattern + lambda_function_name are used.
EOT
  type = list(object({
    event_pattern        = string
    lambda_function_name = string
  }))
  default = []
}
