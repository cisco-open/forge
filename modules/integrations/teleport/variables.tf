variable "aws_profile" {
  type        = string
  description = "AWS profile to use."
}

variable "aws_region" {
  type        = string
  description = "Assuming single region for now."
}

variable "default_tags" {
  type        = map(string)
  description = "A map of tags to apply to resources."
}

variable "tags" {
  type        = map(string)
  description = "A map of tags to apply to resources."
}

variable "tenants" {
  type        = list(string)
  description = "List of tenants to create roles for."
}

variable "teleport_config" {
  type = object({
    cluster_name                = string
    teleport_iam_role_to_assume = string
  })
  description = "Map of IAM roles to assume for teleport access, including EKS cluster ARNs and other roles."
}
