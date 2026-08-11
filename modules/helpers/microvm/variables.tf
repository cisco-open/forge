variable "aws_profile" {
  type        = string
  description = "AWS profile to use."
}

variable "aws_region" {
  type        = string
  description = "AWS region in which to create the Lambda MicroVM prerequisites."
}

variable "default_tags" {
  type        = map(string)
  description = "A map of default tags to apply to resources."
}

variable "tags" {
  type        = map(string)
  description = "A map of module-specific tags to apply to resources."
}

variable "artifact_bucket_name" {
  type        = string
  description = "Optional name for the regional MicroVM build-artifact bucket. The default includes the account ID and region."
  default     = null
  nullable    = true

  validation {
    condition     = var.artifact_bucket_name == null || length(var.artifact_bucket_name) > 0
    error_message = "artifact_bucket_name must be null or a non-empty string."
  }
}

variable "artifact_retention_days" {
  type        = number
  description = "Number of days to retain current and noncurrent MicroVM build artifacts."
  default     = 30

  validation {
    condition     = var.artifact_retention_days >= 1 && var.artifact_retention_days <= 3650
    error_message = "artifact_retention_days must be between 1 and 3650."
  }
}

variable "image_name_prefix" {
  type        = string
  description = "IAM namespace prefix reserved for externally published Lambda MicroVM image names. This module does not create or enumerate images."

  validation {
    condition = (
      length(var.image_name_prefix) >= 1
      && length(var.image_name_prefix) <= 62
      && can(regex("^[a-zA-Z0-9-_]+$", var.image_name_prefix))
    )
    error_message = "image_name_prefix must be a 1 to 62 character IAM namespace containing only letters, numbers, hyphens, or underscores; the publisher validates each complete image name."
  }
}

variable "ecr_repository_arns" {
  type        = set(string)
  description = "Optional regional ECR repository ARNs from which MicroVM image builds can pull runner base images."
  default     = []
}

variable "network_connectors" {
  type = map(object({
    name             = string
    vpc_id           = string
    subnet_ids       = set(string)
    network_protocol = optional(string, "IPv4")
  }))
  description = "Regional Lambda MicroVM Network Connectors keyed by a stable consumer-defined identity."

  validation {
    condition     = length(var.network_connectors) > 0
    error_message = "network_connectors must contain at least one connector."
  }

  validation {
    condition = alltrue([
      for connector in values(var.network_connectors) : (
        length(connector.name) >= 1
        && length(connector.name) <= 64
        && can(regex("^[a-zA-Z0-9_-]+$", connector.name))
      )
    ])
    error_message = "Each network connector name must contain only letters, numbers, hyphens, or underscores and be at most 64 characters."
  }

  validation {
    condition = (
      length(distinct([for connector in values(var.network_connectors) : connector.name])) == length(var.network_connectors)
    )
    error_message = "Each network connector name must be unique within the region."
  }

  validation {
    condition = alltrue([
      for connector in values(var.network_connectors) : can(regex("^vpc-[0-9a-f]+$", connector.vpc_id))
    ])
    error_message = "Each network connector vpc_id must be a valid VPC ID."
  }

  validation {
    condition = alltrue([
      for connector in values(var.network_connectors) : (
        length(connector.subnet_ids) >= 1
        && length(connector.subnet_ids) <= 16
        && alltrue([
          for subnet_id in connector.subnet_ids : can(regex("^subnet-[0-9a-f]+$", subnet_id))
        ])
      )
    ])
    error_message = "Each network connector must contain 1 to 16 valid subnet IDs."
  }

  validation {
    condition = alltrue([
      for connector in values(var.network_connectors) : contains(["IPv4", "DualStack"], connector.network_protocol)
    ])
    error_message = "Each network connector network_protocol must be IPv4 or DualStack."
  }
}
