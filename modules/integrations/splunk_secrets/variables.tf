variable "aws_profile" {
  description = "AWS profile to use."
  type        = string
}

variable "aws_region" {
  type        = string
  description = "Default AWS region."
  default     = "us-east-1"
}

variable "replica_regions" {
  description = "List of regions to replicate the secret"
  type        = list(string)
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "A map of tags to apply to resources."
}

variable "default_tags" {
  type        = map(string)
  description = "A map of tags to apply to resources."
}
