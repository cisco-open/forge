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
      for runner_config in values(var.ec2_deployment_specs.runner_specs) :
      length([
        for provider_type, provider_config in runner_config.compute_provider : provider_type
        if provider_config != null
      ]) == 1
    ])
    error_message = "Each runner_specs entry must configure exactly one compute provider: ec2 or microvm."
  }

  description = <<-EOT
  Compute deployment configuration for GitHub Actions runners.

  Top-level fields:
    - lambda_subnet_ids: Subnets where runner-related lambdas execute.
      These can be more permissive than the runner subnets.
    - subnet_ids       : Default subnets for compute providers that use the VPC.
    - vpc_id           : VPC that contains both runner and lambda subnets.
    - runner_specs     : Map of provider-aware runner lanes.

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
    - compute_provider: Exactly one typed provider block: ec2 or microvm.

  compute_provider.ec2 fields:
    - ami_filter      : Name/state filters used to select the runner AMI.
    - ami_kms_key_arn : KMS key ARN used to encrypt AMI EBS volumes.
    - ami_owners      : List of AWS account IDs that own the AMI.
    - instance_types  : Allowed EC2 instance types for runners in this pool.
    - placement       : Optional EC2 placement configuration.
    - license_specifications: Optional EC2 License Manager configuration ARNs.
    - use_dedicated_host: Whether this runner pool should use dedicated hosts.
    - enable_userdata : Whether to inject the standard runner user data.
    - instance_target_capacity_type: EC2 capacity type (spot or on-demand).
    - vpc_id/subnet_ids: Optional per-lane network overrides.
    - block_device_mappings: EBS volume configuration for runner instances.
    - scale_errors    : Retryable EC2 scale-up error codes.

  compute_provider.microvm fields:
    - image_identifier: ARN or ID of the Lambda MicroVM image.
    - image_version   : Optional Lambda MicroVM image version.
    - egress_network_connectors: Optional Lambda MicroVM network connectors.
    - idle_policy/logging/run_hook_payload: Optional runtime behavior.
    - maximum_duration_in_seconds: Optional maximum MicroVM lifetime.
    - environment_variables/tags: Provider-specific runtime configuration.
    - iam             : Optional MicroVM control-plane IAM overrides.
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
