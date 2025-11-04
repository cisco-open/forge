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

variable "logging_retention_in_days" {
  description = "Log retention period in days"
  type        = number
  default     = 3
}

variable "log_level" {
  type        = string
  description = "Log level for application logging (e.g., INFO, DEBUG, WARN, ERROR)"
  default     = "INFO"
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

variable "splunk_hec_sourcetype" {
  description = "Sourcetype to assign to logs ingested via HEC"
  type        = string
}

variable "regions" {
  description = "List of AWS regions where S3 buckets are located"
  type        = list(string)
  default     = ["us-east-1"]
}
