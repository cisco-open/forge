variable "aws_account_id" {
  description = "AWS account ID associated with the infra/backend."
  type        = string
}

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
