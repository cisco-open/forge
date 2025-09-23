variable "aws_profile" {
  type        = string
  description = "AWS profile to use."
}

variable "aws_region" {
  type        = string
  description = "AWS region to use."
}

variable "reader_config" {
  description = "Configuration for IAM role creation and secret retrieval"
  type = object({
    role_name              = string
    role_trust_principals  = list(string)
    source_secret_role_arn = string
    enable_secret_fetch    = bool
    source_secret_arn      = string
    source_secret_region   = string
  })
  default = {
    role_name              = "github-webhook-relay-secret-reader"
    role_trust_principals  = []
    source_secret_role_arn = ""
    enable_secret_fetch    = false
    source_secret_arn      = ""
    source_secret_region   = ""
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "default_tags" {
  type = map(string)
}

variable "webhook_relay_destination_config" {
  description = "All configuration for the destination EventBridge relay"
  type = object({
    name_prefix                = string
    destination_event_bus_name = string
    source_account_id          = string
    targets = list(object({
      event_pattern        = string
      lambda_function_name = string
    }))
  })
  default = {
    name_prefix                = "webhook-relay-destination"
    destination_event_bus_name = "webhook-relay-destination"
    source_account_id          = ""
    targets                    = []
  }
}
