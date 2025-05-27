variable "aws_account_id" {
  type        = string
  description = "AWS account ID (not SL AWS account ID) associated with the infra/backend."
}

variable "aws_profile" {
  type        = string
  description = "AWS profile (i.e. generated via 'sl aws session generate') to use."
}

variable "aws_region" {
  type        = string
  description = "Assuming single region for now."
}

variable "env" {
  type        = string
  description = "Deployment environments."
}

variable "ghes_org" {
  type        = string
  description = "GitHub organization."
}

variable "ghes_url" {
  type        = string
  description = "GitHub Enterprise Server URL."
}

variable "lambda_subnet_ids" {
  type        = list(string)
  description = "So the lambdas can run in our pre-determined subnets. They don't require the same security policy as the runners though."
}

variable "runner_group_name" {
  type        = string
  description = "Name of the group applied to all runners."
}

variable "deployment_config" {
  type = object({
    prefix        = string
    secret_suffix = string
  })
  description = "Prefix for the deployment, used to distinguish resources."
}

variable "ec2_runner_specs" {
  description = "Map of runner specifications"
  type = map(object({
    ami_filter = object({
      name  = list(string)
      state = list(string)
    })
    aws_budget = object({
      budget_limit = number
    })
    ami_kms_key_arn = string
    ami_owners      = list(string)
    runner_labels   = list(string)
    extra_labels    = list(string)
    max_instances   = number
    min_run_time    = number
    instance_types  = list(string)
    pool_config = list(object({
      size                         = number
      schedule_expression          = string
      schedule_expression_timezone = string
    }))
    runner_user                   = string
    enable_userdata               = bool
    instance_target_capacity_type = string
    block_device_mappings = list(object({
      delete_on_termination = bool
      device_name           = string
      encrypted             = bool
      iops                  = number
      kms_key_id            = string
      snapshot_id           = string
      throughput            = number
      volume_size           = number
      volume_type           = string
    }))
  }))
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet(s) in which our runners will be deployed. Supplied by the underlying AWS-based CI/CD stack."
}

variable "tenant" {
  description = "Map of tenant configs"
  type = object({
    name                = string
    iam_roles_to_assume = optional(list(string), [])
    ecr_registries      = optional(list(string), [])
  })
}

variable "vpc_id" {
  type        = string
  description = "VPC in which our runners will be deployed. Supplied by the underlying AWS-based CI/CD stack."
}

variable "arc_cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "arc_runner_specs" {
  description = "Map of runner specifications"
  type = map(object({
    runner_size = object({
      max_runners = number
      min_runners = number
    })
    scale_set_name            = string
    scale_set_type            = string
    container_actions_runner  = string
    container_limits_cpu      = string
    container_limits_memory   = string
    container_requests_cpu    = string
    container_requests_memory = string
  }))
}

variable "tags" {
  type        = map(string)
  description = "A map of tags to apply to resources."
}

variable "default_tags" {
  type        = map(string)
  description = "A map of tags to apply to resources."
}

variable "log_level" {
  type        = string
  description = "Log level for the module."
}
