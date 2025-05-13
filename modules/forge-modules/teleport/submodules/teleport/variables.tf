variable "namespace" {
  description = "Namespace for chart installation"
  type        = string
}

variable "release_name" {
  description = "Name of the Helm release"
  type        = string
}

variable "teleport_config" {
  type = object({
    teleport_iam_role_to_assume = string
  })
  description = "Map of IAM roles to assume for teleport access, including EKS cluster ARNs and other roles."
}

variable "tags" {
  type        = map(string)
  description = "A map of tags to apply to resources."
}
