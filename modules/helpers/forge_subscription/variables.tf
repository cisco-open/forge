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
}

variable "tags" {
  type        = map(string)
  description = "A map of tags to apply to resources."
}

variable "default_tags" {
  type        = map(string)
  description = "A map of tags to apply to resources."
}
