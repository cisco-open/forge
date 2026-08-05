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
    s3-custom-logs = optional(list(object({
      enabled            = bool
      name               = string
      iam_region         = string
      index              = string
      source_type        = string
      sqs_urls           = list(string)
      s3_bucket_patterns = list(string)
      kms_key_arns       = list(string)
    })), [])
    ct-logs = optional(list(object({
      enabled            = bool
      name               = string
      iam_region         = string
      index              = string
      sqs_urls           = list(string)
      s3_bucket_patterns = list(string)
      kms_key_arns       = list(string)
    })), [])
    s3-access-logs = optional(list(object({
      enabled            = bool
      name               = string
      iam_region         = string
      index              = string
      sqs_urls           = list(string)
      s3_bucket_patterns = list(string)
      kms_key_arns       = list(string)
    })), [])
    elb-access-logs = optional(list(object({
      enabled            = bool
      name               = string
      iam_region         = string
      index              = string
      sqs_urls           = list(string)
      s3_bucket_patterns = list(string)
      kms_key_arns       = list(string)
    })), [])
    cf-access-logs = optional(list(object({
      enabled            = bool
      name               = string
      iam_region         = string
      index              = string
      sqs_urls           = list(string)
      s3_bucket_patterns = list(string)
      kms_key_arns       = list(string)
    })), [])
  })
  description = "Configuration for Splunk S3 log inputs grouped by dataset. Each enabled list item creates one Data Manager input."
  default     = {}
  nullable    = false

  validation {
    condition = alltrue([
      for config in concat(
        var.s3_logs_config["s3-custom-logs"],
        var.s3_logs_config["ct-logs"],
        var.s3_logs_config["s3-access-logs"],
        var.s3_logs_config["elb-access-logs"],
        var.s3_logs_config["cf-access-logs"],
        ) : !config.enabled || (
        length(trimspace(config.name)) > 0
        && can(regex("^[a-z]{2}(-gov)?-[a-z]+-[0-9]+$", trimspace(config.iam_region)))
        && length(trimspace(config.index)) > 0
        && length(config.sqs_urls) > 0
        && length(config.s3_bucket_patterns) > 0
        && alltrue([
          for sqs_url in config.sqs_urls :
          can(regex("^https://sqs\\.[^.]+\\.amazonaws\\.com(\\.cn)?/[0-9]{12}/[^/?#]+$", trimspace(sqs_url)))
        ])
        && alltrue([
          for value in concat(
            config.sqs_urls,
            config.s3_bucket_patterns,
            config.kms_key_arns,
          ) : length(trimspace(value)) > 0
        ])
      )
    ])
    error_message = "Every enabled S3 log input must provide a name, valid IAM roles region, non-empty index, at least one regional AWS SQS queue URL, and at least one S3 bucket pattern; configured URLs, patterns, and KMS key ARNs must not be empty."
  }

  validation {
    condition = alltrue([
      for config in var.s3_logs_config["s3-custom-logs"] :
      !config.enabled || length(trimspace(config.source_type)) > 0
    ])
    error_message = "Every enabled s3-custom-logs input must provide source_type."
  }

  validation {
    condition = length(distinct([
      for config in concat(
        var.s3_logs_config["s3-custom-logs"],
        var.s3_logs_config["ct-logs"],
        var.s3_logs_config["s3-access-logs"],
        var.s3_logs_config["elb-access-logs"],
        var.s3_logs_config["cf-access-logs"],
      ) : trimspace(config.name) if config.enabled
      ])) == length([
      for config in concat(
        var.s3_logs_config["s3-custom-logs"],
        var.s3_logs_config["ct-logs"],
        var.s3_logs_config["s3-access-logs"],
        var.s3_logs_config["elb-access-logs"],
        var.s3_logs_config["cf-access-logs"],
      ) : config if config.enabled
    ])
    error_message = "Enabled S3 log input names must be unique across all datasets."
  }

  validation {
    condition = length(distinct(flatten([
      for config in concat(
        var.s3_logs_config["s3-custom-logs"],
        var.s3_logs_config["ct-logs"],
        var.s3_logs_config["s3-access-logs"],
        var.s3_logs_config["elb-access-logs"],
        var.s3_logs_config["cf-access-logs"],
      ) : [for sqs_url in config.sqs_urls : trimspace(sqs_url)] if config.enabled
      ]))) == length(flatten([
      for config in concat(
        var.s3_logs_config["s3-custom-logs"],
        var.s3_logs_config["ct-logs"],
        var.s3_logs_config["s3-access-logs"],
        var.s3_logs_config["elb-access-logs"],
        var.s3_logs_config["cf-access-logs"],
      ) : config.sqs_urls if config.enabled
    ]))
    error_message = "Enabled S3 log inputs must use unique SQS queues."
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
