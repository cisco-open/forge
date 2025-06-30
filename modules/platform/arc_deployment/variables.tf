variable "aws_profile" {
  type        = string
  description = "AWS profile (i.e. generated via 'sl aws session generate') to use."
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
    runner_iam_role_managed_policy_arns = list(string)
    runner_group_name                   = string
    runner_specs = map(object({
      runner_size = object({
        max_runners = number
        min_runners = number
      })
      scale_set_name            = string
      scale_set_type            = string
      container_actions_runner  = string
      container_limits_cpu      = string
      container_limits_memory   = string
      volume_requests_storage   = string
      container_requests_cpu    = string
      container_requests_memory = string
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
