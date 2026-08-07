variable "aws_profile" {
  type        = string
  description = "AWS profile to use."
}

variable "aws_region" {
  type        = string
  description = "Default AWS region."
}

variable "forge" {
  type = object({
    runner_roles = list(string)
    ecr_repositories = object({
      names                  = list(string)
      ecr_access_account_ids = list(string)
      regions                = list(string)
    })
    microvm = optional(object({
      image_name_prefix = string
      regions = optional(map(object({
        ecr_repository_names = optional(set(string), [])
      })), {})
    }))
  })
  description = "Configuration for Forge runners."
  default = {
    runner_roles = []
    ecr_repositories = {
      names                  = []
      ecr_access_account_ids = []
      regions                = []
    }
  }

  validation {
    condition = var.forge.microvm == null ? true : (
      length(var.forge.microvm.image_name_prefix) >= 1
      && length(var.forge.microvm.image_name_prefix) <= 62
      && can(regex("^[a-zA-Z0-9-_]+$", var.forge.microvm.image_name_prefix))
    )
    error_message = "forge.microvm.image_name_prefix must be a 1 to 62 character IAM namespace containing only letters, numbers, hyphens, or underscores."
  }

  validation {
    condition = var.forge.microvm == null ? true : (
      length(var.forge.microvm.regions) > 0
      && alltrue([
        for region, config in var.forge.microvm.regions : (
          can(regex("^[a-z]{2}(-[a-z]+)+-[0-9]+$", region))
          && alltrue([
            for repository_name in config.ecr_repository_names :
            can(regex("^[a-z0-9]+([._/-][a-z0-9]+)*$", repository_name))
          ])
        )
      ])
    )
    error_message = "forge.microvm.regions must contain at least one valid AWS region with valid ECR repository names."
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
