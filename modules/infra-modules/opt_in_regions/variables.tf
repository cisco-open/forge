variable "opt_in_regions" {
  description = "List of opt-in AWS regions to enable"
  type        = list(string)
  default     = []
}
variable "aws_profile" {
  type        = string
  description = "AWS profile to use."
}

variable "aws_region" {
  type        = string
  description = "Default AWS region."
}


variable "default_tags" {
  type        = map(string)
  description = "A map of tags to apply to resources."
}
