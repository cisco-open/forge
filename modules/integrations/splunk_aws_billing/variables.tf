variable "aws_profile" {
  type        = string
  description = "AWS profile (i.e., generated via 'sl aws session generate') to use."
}

variable "aws_region" {
  type        = string
  description = "Default AWS region."
}

variable "splunk_aws_billing_config" {
  type = object({
    splunk_hec_url     = string
    splunk_index       = string
    splunk_metrics_url = string
  })
  description = "Configuration object for Splunk AWS billing integration."
}

variable "tags" {
  type        = map(string)
  description = "A map of tags to apply to resources."
}

variable "default_tags" {
  type        = map(string)
  description = "A map of tags to apply to resources."
}
