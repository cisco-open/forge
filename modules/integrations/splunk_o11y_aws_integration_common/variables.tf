variable "aws_profile" {
  type        = string
  description = "AWS profile to use."
}

variable "aws_region" {
  type        = string
  description = "Default AWS region."
}

variable "integration_name" {
  type        = string
  description = "Name of the integration."
}

variable "integration_regions" {
  type        = list(string)
  description = "List of regions for the integration."
}

variable "splunk_api_url" {
  description = "URL for plunk Observability Cloud API."
  type        = string
}

variable "splunk_organization_id" {
  description = "organization ID for Splunk Observability Cloud."
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
    Existing resources continue to work, but new deployments should disable this.

    Set to false (default) to skip AppRegistry resource creation.
    Set to true only if your account needs AppRegistry for billing/tracking.
  EOT
  type        = bool
  default     = false
}
