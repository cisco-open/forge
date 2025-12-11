variable "aws_profile" {
  type        = string
  description = "AWS profile to use."
}

variable "aws_region" {
  type        = string
  description = "Default AWS region."
  default     = "us-east-1"
}

variable "splunk_cloud" {
  type        = string
  description = "Splunk Cloud endpoint."
}

variable "cloudformation_s3_config" {
  type = object({
    bucket = string
    key    = string
    region = string
  })
  description = "S3 bucket for CloudFormation templates."
}

variable "custom_cloudwatch_log_groups_config" {
  type = object({
    enabled     = bool
    name        = string
    index       = string
    source_type = string
    log_group_name_prefixes = list(object({
      region                = string
      log_group_name_prefix = string
    }))
  })
  description = "Configuration for log groups including source type and name prefixes."
  default = {
    enabled                 = false
    name                    = ""
    index                   = ""
    source_type             = ""
    log_group_name_prefixes = []
  }
}

variable "cloudwatch_log_groups_config" {
  type = object({
    enabled = bool
    name    = string
    datasource = object({
      cwl-api-gateway = optional(object({
        enabled = bool
        index   = string
      }))
      cwl-cloudhsm = optional(object({
        enabled = bool
        index   = string
      }))
      cwl-documentDB = optional(object({
        enabled = bool
        index   = string
      }))
      cwl-eks = optional(object({
        enabled = bool
        index   = string
      }))
      cwl-lambda = optional(object({
        enabled = bool
        index   = string
      }))
      cwl-rds = optional(object({
        enabled = bool
        index   = string
      }))
      cwl-vpc-flow-logs = optional(object({
        enabled = bool
        index   = string
        vpcIds  = any
      }))
    })
    regions = list(string)
  })
  description = "Configuration for log groups including source type and name prefixes."
  default = {
    enabled    = false
    name       = ""
    datasource = {}
    regions    = []
  }
}

variable "security_metadata_config" {
  type = object({
    enabled = bool
    name    = string
    datasource = object({
      cloudtrail = optional(object({
        enabled = bool
        index   = string
      }))
      securityhub = optional(object({
        enabled = bool
        index   = string
      }))
      guardduty = optional(object({
        enabled = bool
        index   = string
      }))
      iam-aa = optional(object({
        enabled = bool
        index   = string
      }))
      iam-cr = optional(object({
        enabled = bool
        index   = string
      }))
      metadata = optional(object({
        enabled = bool
        index   = string
      }))
    })
    regions = list(string)
  })
  description = "Configuration for log groups including source type and name prefixes."
  default = {
    enabled    = false
    name       = ""
    datasource = {}
    regions    = []
  }
}

variable "tags" {
  type        = map(string)
  description = "A map of tags to apply to resources."
}

variable "default_tags" {
  type        = map(string)
  description = "A map of tags to apply to resources."
}
