variable "splunk_cloud" {
  type        = string
  description = "Splunk Cloud endpoint."
}

variable "splunk_cloud_input_json" {
  type        = string
  description = "Splunk Cloud input JSON."
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources."
}

variable "tags_all" {
  type        = map(string)
  description = "All Tags to apply to resources."
}

variable "cloudformation_s3_config" {
  type = object({
    bucket = string
    key    = string
  })
  description = "S3 bucket for CloudFormation templates."
}
