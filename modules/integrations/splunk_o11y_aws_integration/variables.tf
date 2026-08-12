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

variable "splunk_ingest_token_region" {
  description = "AWS region containing the Splunk ingest token secret. Defaults to aws_region."
  type        = string
  default     = null
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
