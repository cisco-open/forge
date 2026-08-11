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
    runner_specs = map(object({
      runner_labels         = list(string)
      runner_os             = string
      runner_architecture   = string
      extra_labels          = list(string)
      enable_dynamic_labels = optional(bool, false)
      aws_dynamic_labels_policy = optional(object({
        blocked_keys = optional(list(string), [])
        restricted_keys = optional(map(object({
          allowed = optional(list(string), [])
          denied  = optional(list(string), [])
          max     = optional(string, null)
        })), {})
      }), null)
      lambda_event_source_mapping_batch_size                         = optional(number, 10)
      lambda_event_source_mapping_maximum_batching_window_in_seconds = optional(number, 0)
      redrive_build_queue = optional(object({
        enabled         = optional(bool, true)
        maxReceiveCount = optional(number, 10)
      }), {})
      max_instances = number
      min_run_time  = number
      pool_config = list(object({
        size                         = number
        schedule_expression          = string
        schedule_expression_timezone = string
      }))
      runner_user = string
      compute_provider = object({
        ec2 = optional(object({
          ami_filter = object({
            name  = list(string)
            state = list(string)
          })
          ami_kms_key_arn = string
          ami_owners      = list(string)
          instance_types  = list(string)
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
          use_dedicated_host            = optional(bool, false)
          enable_userdata               = bool
          instance_target_capacity_type = string
          vpc_id                        = optional(string, null)
          subnet_ids                    = optional(list(string), null)
          scale_errors                  = optional(list(string), [])
          block_device_mappings = list(object({
            delete_on_termination      = bool
            device_name                = string
            encrypted                  = bool
            iops                       = number
            kms_key_id                 = string
            snapshot_id                = string
            throughput                 = number
            volume_initialization_rate = optional(number)
            volume_size                = number
            volume_type                = string
          }))
        }), null)
        microvm = optional(object({
          image_identifier          = string
          image_version             = optional(string, null)
          egress_network_connectors = optional(list(string), [])
          idle_policy = optional(object({
            max_idle_duration_seconds  = number
            suspended_duration_seconds = number
            auto_resume_enabled        = bool
          }), null)
          logging = optional(object({
            cloud_watch = optional(object({
              log_group  = optional(string, null)
              log_stream = optional(string, null)
            }), null)
            disabled = optional(bool, false)
          }), null)
          run_hook_payload            = optional(string, null)
          maximum_duration_in_seconds = optional(number, null)
          environment_variables       = optional(map(string), {})
          tags                        = optional(map(string), {})
          iam = optional(object({
            resource_arns = optional(list(string), ["*"])
            actions = optional(object({
              scale_up   = optional(list(string), null)
              scale_down = optional(list(string), null)
            }), {})
            additional_policy_json = optional(object({
              scale_up = optional(string, null)
            }), {})
            managed_policy_arns = optional(object({
              scale_up = optional(string, null)
              pool     = optional(string, null)
            }), {})
          }), {})
        }), null)
      })
    }))
  })

  validation {
    condition = alltrue([
      for runner_config in values(var.runner_configs.runner_specs) :
      length([
        for provider_type, provider_config in runner_config.compute_provider : provider_type
        if provider_config != null
      ]) == 1
    ])
    error_message = "Each runner_specs entry must configure exactly one compute provider: ec2 or microvm."
  }
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
