variable "aws_profile" {
  type        = string
  description = "AWS profile (i.e. generated via 'sl aws session generate') to use."
}

variable "aws_region" {
  type        = string
  description = "Assuming single region for now."
}

variable "tags" {
  type        = map(string)
  description = "A map of tags to apply to resources."
}

variable "default_tags" {
  type        = map(string)
  description = "A map of tags to apply to resources."
}
