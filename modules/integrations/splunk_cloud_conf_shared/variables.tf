variable "aws_profile" {
  type        = string
  description = "AWS profile to use."
}

variable "aws_region" {
  type        = string
  description = "Assuming single region for now."
}

variable "default_tags" {
  type        = map(string)
  description = "A map of tags to apply to resources."
}

variable "splunk_conf" {
  type = object({
    splunk_cloud = string
    acl = object({
      app     = string
      owner   = string
      sharing = string
      read    = list(string)
      write   = list(string)
    })
    index        = string
    tenant_names = list(string)
  })
}
