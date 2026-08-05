variable "splunk_cloud" {
  type        = string
  description = "Splunk Cloud endpoint."
}

variable "splunk_cloud_input_json" {
  type        = string
  description = "Splunk Cloud input JSON."
}

variable "stack_name_prefix" {
  type        = string
  description = "CloudFormation stack name prefix for the Splunk data input."
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
