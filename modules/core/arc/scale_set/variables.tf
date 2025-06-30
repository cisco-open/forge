variable "chart_name" {
  description = "Chart URL for the Helm chart"
  type        = string
}

variable "chart_version" {
  description = "Chart version for the Helm chart"
  type        = string
}

variable "container_actions_runner" {
  description = "Container Actions Runner"
  type        = string
}

variable "controller" {
  type = object({
    namespace       = string
    service_account = string
  })
  description = <<EOT
    controller = {
      namespace: "Namespace for the controller."
      service_account: "Service Account Name of the controller."
    }
EOT
}
variable "iam_role_name" {
  description = "The name of the Iam Role"
  type        = string
}

variable "namespace" {
  description = "Namespace for chart installation"
  type        = string
}

variable "release_name" {
  description = "Name of the Helm release"
  type        = string
}

variable "ghes_org" {
  type        = string
  description = "GitHub organization."
}

variable "ghes_url" {
  type        = string
  description = "GitHub Enterprise Server URL."
}

variable "runner_group_name" {
  type        = string
  description = "Name of the group applied to all runners."
}

variable "runner_iam_role_managed_policy_arns" {
  type        = list(string)
  description = "Attach AWS or customer-managed IAM policies (by ARN) to the runner IAM role"
}

variable "tags" {
  type        = map(string)
  description = "A map of tags to apply to resources."
}

variable "runner_size" {
  type = object({
    max_runners = number
    min_runners = number
  })
  description = <<EOT
    runner_size = {
      max_runners: "Maximum number of runners."
      min_runners: "Minimum number of runners."
    }
EOT
}

variable "scale_set_name" {
  type        = string
  description = "Name of the scale set."
}

variable "scale_set_type" {
  type        = string
  description = "Type of the scale set(k8s or dind)."
}

variable "service_account" {
  type        = string
  description = "Name of the Service Account."
}

variable "secret_name" {
  type        = string
  description = "Name of the Secret."
}

variable "container_limits_cpu" {
  type        = string
  description = "Container CPU limits."
}

variable "container_limits_memory" {
  type        = string
  description = "Container memory limits."
}

variable "container_requests_cpu" {
  type        = string
  description = "Container CPU requests."
}

variable "container_requests_memory" {
  type        = string
  description = "Container memory requests."
}

variable "volume_requests_storage" {
  type        = string
  description = "Volume storage requests."
}

variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster."
}

variable "container_ecr_registries" {
  type        = list(string)
  description = "List of ECR registries."
}

variable "oidc_provider_arn" {
  type        = string
  description = "OIDC provider ARN for the EKS cluster."
}
