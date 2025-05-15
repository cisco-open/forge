variable "aws_account_id" {
  type        = string
  description = "AWS account ID (not SL AWS account ID) associated with the infra/backend."
}

variable "aws_profile" {
  description = "AWS profile to use."
  type        = string
}

variable "aws_region" {
  description = "Default AWS region."
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
