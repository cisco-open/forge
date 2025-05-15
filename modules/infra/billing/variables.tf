variable "aws_profile" {
  description = "AWS profile to use."
  type        = string
}

variable "aws_region" {
  description = "Assuming single region for now."
  type        = string
}

variable "group_email" {
  type        = string
  description = "Group email (for contacting owners in case of security/compliance issues)."
}

variable "default_tags" {
  type        = map(string)
  description = "A map of tags to apply to resources."
}
