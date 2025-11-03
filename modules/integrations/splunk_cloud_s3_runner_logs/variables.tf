variable "aws_profile" {
  type        = string
  description = "AWS profile (i.e., generated via 'sl aws session generate') to use."
}

variable "aws_region" {
  type        = string
  description = "Default AWS region."
}

variable "tags" {
  type        = map(string)
  description = "A map of tags to apply to resources."
}

variable "default_tags" {
  type        = map(string)
  description = "A map of tags to apply to resources."
}

variable "log_retention_in_days" {
  description = "Log retention period in days"
  type        = number
  default     = 3
}

variable "s3_bucket_names" {
  description = "List of existing S3 bucket names storing GitHub runner job logs"
  type        = list(string)
}

variable "splunk_hec_host" {
  description = "Hostname (without protocol) of Splunk HEC endpoint"
  type        = string
}

variable "splunk_hec_port" {
  description = "Port of Splunk HEC endpoint (e.g. 8088)"
  type        = number
  default     = 8088
}

variable "filter_suffix" {
  description = "S3 object key suffix to filter on"
  type        = string
}
