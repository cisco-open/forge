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
      image_management_policy_arns = optional(set(string), [])
    }), {})
  })
  description = "Configuration for Forge runners."
  default = {
    runner_roles = []
    ecr_repositories = {
      names                  = []
      ecr_access_account_ids = []
      regions                = []
    }
    microvm = {
      image_management_policy_arns = []
    }
  }

  validation {
    condition = alltrue([
      for policy_arn in var.forge.microvm.image_management_policy_arns :
      can(regex("^arn:[^:]+:iam::[0-9]{12}:policy/.+$", policy_arn))
    ])
    error_message = "forge.microvm.image_management_policy_arns must contain valid IAM managed-policy ARNs."
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
