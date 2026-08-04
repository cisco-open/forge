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

variable "s3_logs_config" {
  type = object({
    enabled            = bool
    name               = string
    iam_region         = optional(string, "us-east-1")
    index              = string
    source_type        = string
    sqs_urls           = list(string)
    s3_bucket_patterns = list(string)
    kms_key_arns       = list(string)
  })
  description = "Configuration for S3 logs ingested through SQS notifications."
  default = {
    enabled            = false
    name               = ""
    iam_region         = "us-east-1"
    index              = ""
    source_type        = ""
    sqs_urls           = []
    s3_bucket_patterns = []
    kms_key_arns       = []
  }

  validation {
    condition = !var.s3_logs_config.enabled || (
      length(trimspace(var.s3_logs_config.name)) > 0
      && can(regex("^[a-z]{2}(-gov)?-[a-z]+-[0-9]+$", trimspace(var.s3_logs_config.iam_region)))
      && length(trimspace(var.s3_logs_config.index)) > 0
      && length(trimspace(var.s3_logs_config.source_type)) > 0
      && length(var.s3_logs_config.sqs_urls) > 0
      && length(var.s3_logs_config.s3_bucket_patterns) > 0
      && alltrue([
        for sqs_url in var.s3_logs_config.sqs_urls :
        can(regex("^https://sqs\\.[^.]+\\.amazonaws\\.com(\\.cn)?/[0-9]{12}/[^/?#]+$", trimspace(sqs_url)))
      ])
      && alltrue([
        for value in concat(
          var.s3_logs_config.sqs_urls,
          var.s3_logs_config.s3_bucket_patterns,
          var.s3_logs_config.kms_key_arns,
        ) : length(trimspace(value)) > 0
      ])
    )
    error_message = "When s3_logs_config is enabled, name, a valid IAM roles region, index, source_type, at least one regional AWS SQS queue URL, and at least one S3 bucket pattern must be provided; configured URLs, patterns, and KMS key ARNs must not be empty."
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
