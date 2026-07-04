variable "aws_profile" {
  description = "AWS profile to use."
  type        = string
}

variable "aws_region" {
  description = "Assuming single region for now."
  type        = string
}

variable "tags" {
  type        = map(string)
  description = "A map of tags to apply to resources."
}

variable "default_tags" {
  type        = map(string)
  description = "A map of tags to apply to resources."
}
variable "forge_role_arn" {
  type        = string
  description = "ARN of the role to assume for Cloud Custodian."
}
