variable "aws_region" {
  type        = string
  description = "Assuming single region for now."
}

variable "runner_configs" {
  type = object({
    env                       = string
    prefix                    = string
    ghes_url                  = string
    ghes_org                  = string
    log_level                 = string
    logging_retention_in_days = string
    github_app = object({
      key_base64     = string
      id             = string
      webhook_secret = string
    })
    runner_iam_role_managed_policy_arns = list(string)
    runner_group_name                   = string
    scale_errors                        = optional(list(string), [])
    runner_specs = map(object({
      ami_filter = object({
        name  = list(string)
        state = list(string)
      })
      ami_kms_key_arn     = string
      ami_owners          = list(string)
      runner_labels       = list(string)
      runner_os           = string
      runner_architecture = string
      extra_labels        = list(string)
      max_instances       = number
      min_run_time        = number
      instance_types      = list(string)
      license_specifications = optional(list(object({
        license_configuration_arn = string
      })), null)
      placement = optional(object({
        affinity                = optional(string)
        availability_zone       = optional(string)
        group_id                = optional(string)
        group_name              = optional(string)
        host_id                 = optional(string)
        host_resource_group_arn = optional(string)
        spread_domain           = optional(string)
        tenancy                 = optional(string)
        partition_number        = optional(number)
      }), null)
      pool_config = list(object({
        size                         = number
        schedule_expression          = string
        schedule_expression_timezone = string
      }))
      runner_user                   = string
      enable_userdata               = bool
      instance_target_capacity_type = string
      vpc_id                        = optional(string, null)
      subnet_ids                    = optional(list(string), null)
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
  })
}

variable "network_configs" {
  type = object({
    vpc_id            = string
    subnet_ids        = list(string)
    lambda_vpc_id     = string
    lambda_subnet_ids = list(string)
  })
}

variable "tenant_configs" {
  type = object({
    ecr_registries = list(string)
    tags           = map(string)
  })
}
