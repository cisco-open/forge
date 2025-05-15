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
