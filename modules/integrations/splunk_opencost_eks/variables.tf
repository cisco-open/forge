variable "aws_profile" {
  type        = string
  description = "AWS profile to use."
  default     = null
}

variable "aws_region" {
  type        = string
  description = "Default AWS region."
  default     = null
}

variable "default_tags" {
  type        = map(string)
  description = "A map of tags to apply to resources."
  default     = {}
}

variable "cluster_name" {
  type        = string
  description = "The EKS cluster name and OpenCost default cluster ID."
}
