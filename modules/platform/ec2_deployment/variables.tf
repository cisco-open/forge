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
        ec2 = object({
          metadata_options = optional(object({
            instance_metadata_tags      = optional(string, "enabled")
            http_endpoint               = optional(string, "enabled")
            http_tokens                 = optional(string, "required")
            http_put_response_hop_limit = optional(number, 1)
          }), {})
          ami = optional(object({
            filter = optional(map(list(string)), { state = ["available"] })
            owners = optional(list(string), ["amazon"])
            id_ssm_parameter = optional(object({
              arn = string
            }), null)
            kms_key = optional(object({
              arn = string
            }), null)
          }), null)
          block_device_mappings = optional(list(object({
            delete_on_termination      = optional(bool, true)
            device_name                = optional(string, "/dev/xvda")
            encrypted                  = optional(bool, true)
            iops                       = optional(number)
            kms_key_id                 = optional(string)
            snapshot_id                = optional(string)
            throughput                 = optional(number)
            volume_initialization_rate = optional(number)
            volume_size                = number
            volume_type                = optional(string, "gp3")
            })), [{
            volume_size = 30
          }])
          create_service_linked_role_spot = optional(bool, false)
          credit_specification            = optional(string, null)
          ebs_optimized                   = optional(bool, false)
          cloudwatch_agent = optional(object({
            enabled = optional(bool, true)
            config  = optional(string, null)
          }), {})
          binaries_syncer = optional(object({
            enabled = optional(bool, true)
          }), {})
          detailed_monitoring_enabled = optional(bool, false)
          ssm_enabled                 = optional(bool, false)
          user_data = optional(object({
            enabled               = optional(bool, true)
            template              = optional(string, null)
            content               = optional(string, null)
            pre_install           = optional(string, "")
            post_install          = optional(string, "")
            debug_logging_enabled = optional(bool, false)
          }), {})
          instance_allocation_strategy  = optional(string, "lowest-price")
          instance_max_spot_price       = optional(string, null)
          instance_target_capacity_type = optional(string, "spot")
          instance_type_priorities      = optional(map(number), null)
          instance_types                = list(string)
          additional_security_group_ids = optional(list(string), [])
          instance_profile = optional(object({
            name = string
          }), null)
          enable_on_demand_failover_for_errors = optional(list(string), [])
          scale_errors = optional(list(string), [
            "UnfulfillableCapacity",
            "MaxSpotInstanceCountExceeded",
            "TargetCapacityLimitExceededException",
            "RequestLimitExceeded",
            "ResourceLimitExceeded",
            "MaxSpotInstanceCountExceeded",
            "MaxSpotFleetRequestCountExceeded",
            "InsufficientInstanceCapacity",
            "InsufficientCapacityOnHost",
          ])
          subnet_ids = optional(list(string), null)
          vpc_id     = optional(string, null)
          cpu_options = optional(object({
            core_count            = optional(number)
            threads_per_core      = optional(number)
            amd_sev_snp           = optional(string)
            nested_virtualization = optional(string)
          }), null)
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
          license_specifications = optional(list(object({
            license_configuration_arn = string
          })), [])
          use_dedicated_host = optional(bool, false)
          log_files = optional(list(object({
            log_group_name   = string
            prefix_log_group = bool
            file_path        = string
            log_stream_name  = string
            log_class        = optional(string, "STANDARD")
          })), null)
          tags = optional(map(string), {})
        })
      })
    }))
  })

  validation {
    condition = alltrue([
      for runner_config in values(var.runner_configs.runner_specs) :
      length(runner_config.compute_provider.ec2.ami[*]) == 1
      && try(length(runner_config.compute_provider.ec2.ami.id_ssm_parameter[*]) == 0, false)
    ])
    error_message = "Forge EC2 runner_specs must configure a module-managed ami block; ami = null and external ami.id_ssm_parameter ownership are not supported."
  }

  validation {
    condition = alltrue([
      for runner_config in values(var.runner_configs.runner_specs) :
      !runner_config.compute_provider.ec2.user_data.debug_logging_enabled
    ])
    error_message = "Forge EC2 runner_specs do not support user_data.debug_logging_enabled while the upstream v1 adapter is active."
  }

  validation {
    condition = alltrue([
      for runner_config in values(var.runner_configs.runner_specs) :
      length(runner_config.compute_provider.ec2.instance_profile[*]) == 0
    ])
    error_message = "Forge EC2 runner_specs do not support an external instance_profile."
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
