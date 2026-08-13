variable "aws_region" {
  type        = string
  description = "Assuming single region for now."
}

variable "runner_configs" {
  type = object({
    env                       = string
    prefix                    = string
    ghes_url                  = string
    log_level                 = string
    logging_retention_in_days = string
    github_app = object({
      key_base64     = string
      id             = string
      webhook_secret = string
    })
    runner_iam_role_managed_policy_arns = list(string)
    runner_specs = map(object({
      tags = optional(map(string), {})

      runner = object({
        os                     = string
        architecture           = string
        boot_time_in_minutes   = optional(number, 5)
        disable_default_labels = optional(bool, false)
        extra_labels           = optional(list(string), [])
        group_name             = optional(string, "Default")
        name_prefix            = optional(string, "")
        run_as_root            = optional(bool, false)
        run_as                 = optional(string, "ec2-user")
        maximum_count          = number
        ephemeral              = optional(bool, false)
        jit_config_enabled     = optional(bool, null)
        auto_update_disabled   = optional(bool, false)
        tags                   = optional(map(string), {})
        hooks = optional(object({
          job_started   = optional(string, "")
          job_completed = optional(string, "")
        }), {})
        iam = optional(object({
          role = optional(object({
            arn = string
          }), null)
          managed_policy_arns          = optional(map(string), {})
          additional_trust_policy_json = optional(string, null)
          path                         = optional(string, null)
          permissions_boundary         = optional(string, null)
        }), {})
      })

      github = optional(object({
        organization_runners = optional(bool, false)
      }), {})

      lambda = optional(object({
        tags = optional(map(string), {})
      }), {})

      queue = optional(object({
        delay_webhook_event            = optional(number, 30)
        job_queue_retention_in_seconds = optional(number, 86400)
        event_source_mapping = optional(object({
          batch_size                         = optional(number, null)
          maximum_batching_window_in_seconds = optional(number, null)
        }), {})
        redrive_build_queue = optional(object({
          enabled         = bool
          maxReceiveCount = number
          }), {
          enabled         = false
          maxReceiveCount = null
        })
        tags = optional(map(string), {})
      }), {})

      scale_up = optional(object({
        reserved_concurrent_executions = optional(number, 1)
        job_queued_check_enabled       = optional(bool, null)
        tags                           = optional(map(string), {})
      }), {})

      scale_down = optional(object({
        schedule_expression             = optional(string, "cron(*/5 * * * ? *)")
        minimum_running_time_in_minutes = optional(number, null)
        tags                            = optional(map(string), {})
        idle_config = optional(list(object({
          cron             = string
          timeZone         = string
          idleCount        = number
          evictionStrategy = optional(string, "oldest_first")
        })), [])
      }), {})

      pool = optional(object({
        config = optional(list(object({
          schedule_expression          = string
          schedule_expression_timezone = optional(string)
          size                         = number
        })), [])
        runner_owner = optional(string, null)
        tags         = optional(map(string), {})
      }), {})

      job_retry = optional(object({
        enabled          = optional(bool, false)
        delay_in_seconds = optional(number, 300)
        delay_backoff    = optional(number, 2)
        max_attempts     = optional(number, 1)
        tags             = optional(map(string), {})
        lambda = optional(object({
          memory_size                    = optional(number, 256)
          reserved_concurrent_executions = optional(number, 1)
          timeout                        = optional(number, 30)
        }), {})
      }), {})

      ssm = optional(object({
        tags = optional(map(string), {})
        kms_key = optional(object({
          arn = string
        }), null)
        parameters = optional(object({
          tags = optional(map(string), {})
        }), {})
        housekeeper = optional(object({
          tags = optional(map(string), {})
        }), {})
      }), {})

      observability = optional(object({
        logs = optional(object({
          tags = optional(map(string), {})
        }), {})
      }), {})

      compute_provider = object({
        ec2 = optional(object({
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
        }), null)
      })

      matcherConfig = object({
        labelMatchers           = list(list(string))
        exactMatch              = optional(bool, false)
        bidirectionalLabelMatch = optional(bool, false)
        priority                = optional(number, 999)
        enableDynamicLabels     = optional(bool, false)
        awsDynamicLabelsPolicy = optional(object({
          blocked_keys = optional(list(string), [])
          restricted_keys = optional(map(object({
            allowed = optional(list(string), [])
            denied  = optional(list(string), [])
            max     = optional(string, null)
          })), {})
        }), null)
      })
    }))
  })

  validation {
    condition = alltrue([
      for runner_config in values(var.runner_configs.runner_specs) :
      try(
        length(runner_config.compute_provider.ec2[*]) == 1
        && length(runner_config.compute_provider.ec2.ami[*]) == 1
        && length(runner_config.compute_provider.ec2.ami.id_ssm_parameter[*]) == 0,
        false,
      )
    ])
    error_message = "Forge EC2 runner_specs must configure a module-managed ami block; ami = null and external ami.id_ssm_parameter ownership are not supported."
  }

  validation {
    condition = alltrue([
      for runner_config in values(var.runner_configs.runner_specs) :
      try(!runner_config.compute_provider.ec2.user_data.debug_logging_enabled, false)
    ])
    error_message = "Forge EC2 runner_specs do not support user_data.debug_logging_enabled while the upstream v1 adapter is active."
  }

  validation {
    condition = alltrue([
      for runner_config in values(var.runner_configs.runner_specs) :
      try(
        length(runner_config.compute_provider.ec2.instance_profile[*]) == 0
        && length(runner_config.runner.iam.role[*]) == 0,
        false,
      )
    ])
    error_message = "Forge EC2 runner_specs do not support external runner.iam.role or compute_provider.ec2.instance_profile ownership while the upstream v1 adapter is active."
  }

  validation {
    condition = alltrue([
      for runner_config in values(var.runner_configs.runner_specs) :
      length(runner_config.tags) == 0
      && length(runner_config.runner.tags) == 0
      && length(runner_config.lambda.tags) == 0
      && length(runner_config.queue.tags) == 0
      && length(runner_config.scale_up.tags) == 0
      && length(runner_config.scale_down.tags) == 0
      && length(runner_config.pool.tags) == 0
      && length(runner_config.job_retry.tags) == 0
      && length(runner_config.ssm.tags) == 0
      && length(runner_config.ssm.parameters.tags) == 0
      && length(runner_config.ssm.housekeeper.tags) == 0
      && length(runner_config.observability.logs.tags) == 0
    ])
    error_message = "Forge EC2 runner_specs only support compute_provider.ec2.tags while the upstream v1 adapter is active; all other v2 per-lane tag maps must remain empty."
  }

  validation {
    condition = alltrue([
      for runner_config in values(var.runner_configs.runner_specs) :
      runner_config.runner.iam.additional_trust_policy_json == null
      && runner_config.runner.iam.path == null
      && runner_config.runner.iam.permissions_boundary == null
      && runner_config.job_retry.lambda.reserved_concurrent_executions == 1
      && runner_config.ssm.kms_key == null
    ])
    error_message = "Forge EC2 runner_specs do not support per-lane IAM trust/path/boundary, non-default job-retry Lambda reserved concurrency, or per-lane SSM KMS keys while the upstream v1 adapter is active."
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
