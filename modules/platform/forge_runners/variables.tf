variable "aws_profile" {
  type        = string
  description = "AWS profile to use."
}

variable "aws_region" {
  type        = string
  description = "AWS region where Forge runners and supporting infrastructure are deployed."
}

variable "ec2_deployment_specs" {
  type = object({
    lambda_subnet_ids = list(string)
    subnet_ids        = list(string)
    lambda_vpc_id     = string
    vpc_id            = string
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
      for runner_config in values(var.ec2_deployment_specs.runner_specs) :
      length(runner_config.compute_provider.ec2.ami[*]) == 1
      && try(length(runner_config.compute_provider.ec2.ami.id_ssm_parameter[*]) == 0, false)
    ])
    error_message = "Forge EC2 runner_specs must configure a module-managed ami block; ami = null and external ami.id_ssm_parameter ownership are not supported."
  }

  validation {
    condition = alltrue([
      for runner_config in values(var.ec2_deployment_specs.runner_specs) :
      length(runner_config.compute_provider.ec2.instance_profile[*]) == 0
    ])
    error_message = "Forge EC2 runner_specs do not support an external instance_profile."
  }

  description = <<-EOT
  Compute deployment configuration for GitHub Actions runners.

  Top-level fields:
    - lambda_subnet_ids: Subnets where runner-related lambdas execute.
      These can be more permissive than the runner subnets.
    - subnet_ids       : Default subnets for EC2 runners.
    - vpc_id           : VPC that contains both runner and lambda subnets.
    - runner_specs     : Map of EC2 runner lanes.

  runner_specs[*] object fields:
    - runner_labels   : Base GitHub labels applied to jobs for this pool.
    - runner_os       : Runner operating system (for example, linux).
    - runner_architecture: CPU architecture (for example, x86_64 or arm64).
    - extra_labels    : Additional GitHub labels that further specialize
                        this runner pool.
    - enable_dynamic_labels: Enables dynamic `ghr-` labels for this runner
                        pool.
    - aws_dynamic_labels_policy: Optional policy for `ghr-ec2-*` labels for
                        this runner pool.
    - lambda_event_source_mapping_batch_size: Optional maximum number of queued
                        jobs passed to the scale-up Lambda per invocation.
    - lambda_event_source_mapping_maximum_batching_window_in_seconds: Optional
                        maximum time to collect queued jobs before invoking the
                        scale-up Lambda.
    - redrive_build_queue: Optional dead-letter queue redrive configuration.
                        Controls whether redrive is enabled and how many times a
                        message can be received before moving to the dead-letter
                        queue.
    - max_instances   : Maximum number of runners in this pool.
    - min_run_time    : Minimum job run time (in minutes) before a runner
                        is eligible for scale-down.
    - pool_config     : List of pool size schedules (size + cron expression
                        and optional time zone) controlling baseline capacity.
    - runner_user     : OS user under which the GitHub runner process runs.
    - compute_provider: Nested upstream EC2 provider configuration.

  compute_provider.ec2 fields:
    - ami             : Upstream-compatible EC2 AMI configuration.
                        Forge requires a module-managed AMI block; null and
                        external AMI parameter ownership are unsupported.
    - metadata_options: EC2 instance metadata service configuration.
    - block_device_mappings: EBS mappings for runner instances.
    - cloudwatch_agent/binaries_syncer/user_data: Runner bootstrap configuration.
    - instance_types and allocation fields: EC2 Fleet capacity configuration.
    - vpc_id/subnet_ids/additional_security_group_ids: Per-lane networking.
    - cpu_options/placement/license_specifications: EC2 launch-template options.
    - instance_profile: Upstream contract field reserved for future Forge support.
    - log_files/tags  : EC2 logging and resource tags.
  EOT
}


variable "deployment_config" {
  type = object({
    deployment_prefix = string
    secret_suffix     = string
    env               = string
    github_app = object({
      id              = string
      client_id       = string
      installation_id = string
      name            = string
    })
    github = object({
      ghes_org             = string
      ghes_url             = string
      repository_selection = string
      runner_group_name    = string
    })
    tenant = object({
      name                         = string
      iam_roles_to_assume          = optional(list(string), [])
      ecr_registries               = optional(list(string), [])
      github_logs_reader_role_arns = optional(list(string), [])
    })
  })

  validation {
    condition     = contains(["all", "selected"], var.deployment_config.github.repository_selection)
    error_message = "repository_selection must be 'all' or 'selected'."
  }

  validation {
    condition     = trimspace(var.deployment_config.github.ghes_org) != ""
    error_message = "ghes_org must be non-empty."
  }

  description = <<-EOT
  High-level deployment configuration for a Forge runner installation.

  Top-level fields:
    - deployment_prefix: Prefix used when naming resources (for example,
      log groups, KMS keys, and SSM parameters).
    - env              : Logical environment name (for example, dev, stage,
      prod). Used for tagging and dashboards.

  github_app object:
    - id             : Numeric GitHub App ID.
    - client_id      : OAuth client ID for the app.
    - installation_id: GitHub App installation ID for this tenant.
    - name           : GitHub App name, used to build URLs and logs.

  github object:
    - ghes_org            : GitHub organization that owns the repos where
      runners will be used.
    - ghes_url            : GitHub.com or GHES base URL. Empty string implies
      public github.com.
    - repository_selection: Scope for runners (all or selected repositories).
    - runner_group_name   : GitHub runner group to attach new runners to.

  tenant object:
    - name                        : Tenant identifier used in naming and
      tagging.
    - iam_roles_to_assume         : Optional list of IAM role ARNs that
      runners are allowed to assume for workload execution.
    - ecr_registries              : Optional list of ECR registry URLs that
      runners may need to pull images from.
    - github_logs_reader_role_arns: Optional list of IAM roles that can read
      GitHub Actions logs for this tenant.
  EOT
}

variable "arc_deployment_specs" {
  type = object({
    cluster_name    = string
    migrate_cluster = optional(bool, false)
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
      container_requests_cpu       = string
      container_requests_memory    = string
      volume_requests_storage_size = string
      volume_requests_storage_type = string
    }))
  })

  description = <<-EOT
  Deployment configuration for Azure Container Apps (ARC) runners.

  Top-level fields:
    - cluster_name   : Name of the EKS cluster used for ARC runners.
    - migrate_cluster: Optional flag to indicate a one-time migration or
      blue/green cutover of the ARC runner cluster.
    - runner_specs   : Map of ARC runner pool keys to their sizing and
      container resource settings.

  runner_specs[*] object fields:
    - runner_size.max_runners: Maximum concurrent ARC runners for this pool.
    - runner_size.min_runners: Minimum number of warm runners.
    - scale_set_name         : Logical name for the scale set / pool.
    - scale_set_type         : Backing type for the scale set (for example,
      kubernetes or containerapp, depending on integration).
    - scale_set_labels       : GitHub runner labels advertised by this ARC
      scale set.
    - container_images            : Container images used by the ARC runner,
                                    sidecars, and DinD containers.
    - container_limits_cpu        : CPU limit for the runner container.
    - container_limits_memory     : Memory limit for the runner container.
    - container_requests_cpu      : CPU request (baseline reservation).
    - container_requests_memory   : Memory request (baseline reservation).
    - volume_requests_storage_size: Size of attached storage for the runner.
    - volume_requests_storage_type: Storage class or type for attached volume.
  EOT
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
  description = "Log level for application logging (e.g., INFO, DEBUG, WARN, ERROR)"
}

variable "logging_retention_in_days" {
  type        = string
  description = "Logging retention period in days."
}

variable "github_webhook_relay" {
  description = <<-EOT
  Configuration for the (optional) webhook relay source module.
  If enabled=true we provision the API Gateway + source EventBridge forwarding rule.
  destination_event_bus_name must already exist or be created in the destination account (or via the destination submodule run there).
  EOT
  type = object({
    enabled                     = bool
    destination_account_id      = optional(string)
    destination_event_bus_name  = optional(string)
    destination_region          = optional(string)
    destination_reader_role_arn = optional(string)
  })
  default = {
    enabled                     = false
    destination_account_id      = ""
    destination_event_bus_name  = ""
    destination_region          = ""
    destination_reader_role_arn = ""
  }
}
