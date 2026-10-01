variable "aws_profile" {
  type        = string
  description = "AWS profile to use."
}

variable "aws_region" {
  type        = string
  description = "Default AWS region."
}

variable "splunk_ingest_url" {
  description = "URL for Splunk Ingest."
  type        = string
}

variable "template_url" {
  description = "URL for the CloudFormation template."
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

variable "enable_app_registry" {
  description = <<-EOT
    Enable AWS Service Catalog AppRegistry resources.

    AWS deprecated AppRegistry for new customers on July 30, 2026.
    Default: true (enabled) to protect existing deployments from resource destruction.

    Existing accounts: Leave default (AppRegistry continues working for billing/tracking).
    New accounts (post July 30, 2026): Set to false to avoid AccessDeniedException.

    Set to false to skip AppRegistry resource creation.
    Set to true to keep AppRegistry resources (needed for existing deployments).
  EOT
  type        = bool
  default     = true
}
