variable "repository_names" {
  type        = list(string)
  description = "ECR repositories in the provider region that should receive the Forge access policy."
}

variable "ecr_access_account_ids" {
  type        = list(string)
  description = "AWS account IDs allowed to pull images from the ECR repositories."
}
