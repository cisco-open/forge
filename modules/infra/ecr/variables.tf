variable "aws_profile" {
  type        = string
  description = "AWS profile to use."
}

variable "aws_region" {
  type        = string
  description = "Default AWS region."
}

variable "tags" {
  type        = map(string)
  description = "A map of tags to apply to resources."
}

variable "default_tags" {
  type        = map(string)
  description = "A map of tags to apply to resources."
}

variable "repositories" {
  type = list(object({
    repo         = string
    mutability   = string
    scan_on_push = bool
  }))
  description = "A list of ECR repositories to create. Mutability must be 'MUTABLE' or 'IMMUTABLE'."

  validation {
    condition = alltrue([
      for r in var.repositories : contains(["MUTABLE", "IMMUTABLE"], r.mutability)
    ])
    error_message = "Each repository 'mutability' must be either 'MUTABLE' or 'IMMUTABLE'."
  }
}
