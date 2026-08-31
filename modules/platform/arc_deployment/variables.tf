variable "aws_profile" {
  type        = string
  description = "AWS profile to use."
}

variable "aws_region" {
  type        = string
  description = "Assuming single region for now."
}

variable "runner_configs" {
  type = object({
    prefix           = string
    arc_cluster_name = string
    ghes_url         = string
    ghes_org         = string
    github_app = object({
      key_base64      = string
      id              = string
      installation_id = string
    })
    migrate_arc_cluster                 = optional(bool, false)
    runner_iam_role_managed_policy_arns = list(string)
    runner_group_name                   = string
    log_level                           = optional(string, "INFO")
    karpenter_node_pool = optional(object({
      requirements = optional(list(object({
        key        = string
        operator   = string
        values     = list(string)
        min_values = optional(number)
        })), [
        {
          key        = "karpenter.k8s.aws/instance-category"
          operator   = "In"
          values     = ["c", "m", "r"]
          min_values = 2
        },
        {
          key        = "karpenter.k8s.aws/instance-family"
          operator   = "In"
          values     = ["m5", "m5d", "c5", "c5d", "c4", "r4"]
          min_values = 3
        },
        {
          key      = "kubernetes.io/arch"
          operator = "In"
          values   = ["amd64"]
        },
        {
          key      = "kubernetes.io/os"
          operator = "In"
          values   = ["linux"]
        },
        {
          key      = "karpenter.sh/capacity-type"
          operator = "In"
          values   = ["on-demand"]
        },
        {
          key      = "karpenter.k8s.aws/instance-category"
          operator = "In"
          values   = ["c", "m", "r"]
        },
      ])
      cpu_limit            = optional(number, 100)
      consolidation_policy = optional(string, "WhenEmptyOrUnderutilized")
      consolidate_after    = optional(string, "1m")
    }), {})
    runner_specs = map(object({
      runner_size = object({
        max_runners = number
        min_runners = number
      })
      scale_set_name   = string
      scale_set_type   = string
      scale_set_labels = list(string)
      container_images = optional(object({
        actions_runner = optional(string, "ghcr.io/actions/actions-runner:latest")
        busybox        = optional(string, "public.ecr.aws/docker/library/busybox:stable")
        dind_rootless  = optional(string, "public.ecr.aws/docker/library/docker:dind-rootless")
      }), {})
      container_limits_cpu         = string
      container_limits_memory      = string
      volume_requests_storage_size = string
      volume_requests_storage_type = string
      container_requests_cpu       = string
      container_requests_memory    = string
    }))
  })
}

variable "tenant_configs" {
  type = object({
    ecr_registries = list(string)
    tags           = map(string)
    name           = string
  })
}
