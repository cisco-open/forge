variable "aws_profile" {
  type        = string
  description = "AWS profile (i.e. generated via 'sl aws session generate') to use."
}

variable "aws_region" {
  type        = string
  description = "Assuming single region for now."
}

variable "ghes_org" {
  type        = string
  description = "GitHub organization."
}

variable "ghes_url" {
  type        = string
  description = "GitHub Enterprise Server URL."
}

variable "github_app" {
  description = "GitHub App configuration"
  type = object({
    key_base64      = string
    id              = string
    installation_id = string
  })
}

variable "runner_group_name" {
  type        = string
  description = "Name of the group applied to all runners."
}

variable "eks_cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "tags" {
  type        = map(string)
  description = "A map of tags to apply to resources."
}

variable "multi_runner_config" {
  type = map(object({
    runner_set_configs = object({
      release_name  = string
      namespace     = string
      chart_name    = string
      chart_version = string
    })
    runner_config = object({
      runner_size = object({
        max_runners = number
        min_runners = number
      })
      prefix                              = string
      scale_set_name                      = string
      scale_set_type                      = string
      container_limits_cpu                = string
      container_limits_memory             = string
      container_requests_cpu              = string
      container_requests_memory           = string
      volume_requests_storage_size        = string
      volume_requests_storage_type        = string
      container_actions_runner            = string
      container_ecr_registries            = list(string)
      runner_iam_role_managed_policy_arns = list(string)
      controller = object({
        service_account = string
        namespace       = string
      })
    })
  }))
  description = <<EOT
    multi_runner_config = {
      runner_config: {
        runner_size: {
          max_runners: "Maximum number of runners."
          min_runners: "Minimum number of runners."
        }
        controller = {
          service_account: "Service Account Name of the controller."
          namespace: "Namespace for the controller."
        }
        prefix: "Prefix for naming resources."
        scale_set_name: "Name of the scale set."
        runner_iam_role_managed_policy_arns: "Attach AWS or customer-managed IAM policies (by ARN) to the runner IAM role."
      }
      runner_set_configs: {
        release_name: "Name of the Helm release."
        namespace: "Namespace for chart installation."
        chart_name: "Chart name for the Helm chart."
        chart_version: "Chart version for the Helm chart."
      }
    }
EOT
}

variable "controller_config" {
  type = object({
    release_name  = string
    namespace     = string
    chart_name    = string
    chart_version = string
    name          = string
  })
  description = <<EOT
    controller_config = {
      release_name: "Name of the Helm release."
      namespace: "Namespace for chart installation."
      chart_name: "Chart name for the Helm chart."
      chart_version: "Chart version for the Helm chart."
      name: "Name of the controller."
    }
EOT
}

variable "migrate_arc_cluster" {
  type        = bool
  description = "Flag to indicate if the cluster should be migrated."
  default     = false
}
