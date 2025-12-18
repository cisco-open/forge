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
    scale_errors      = optional(list(string), [])
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

  description = <<-EOT
  EC2 deployment configuration for GitHub Actions runners.

  Top-level fields:
    - lambda_subnet_ids: Subnets where runner-related lambdas execute.
      These can be more permissive than the runner subnets.
    - subnet_ids       : Subnets where the EC2 runners are launched.
    - vpc_id           : VPC that contains both runner and lambda subnets.
    - runner_specs     : Map of runner pool keys to their EC2 sizing and
                         scheduling configuration.

  runner_specs[*] object fields:
    - ami_filter      : Name/state filters used to select the runner AMI.
    - ami_kms_key_arn : KMS key ARN used to encrypt AMI EBS volumes.
    - ami_owners      : List of AWS account IDs that own the AMI.
    - runner_labels   : Base GitHub labels applied to jobs for this pool.
    - runner_os       : Runner operating system (for example, linux).
    - runner_architecture: CPU architecture (for example, x86_64 or arm64).
    - extra_labels    : Additional GitHub labels that further specialize
                        this runner pool.
    - max_instances   : Maximum number of EC2 runners in this pool.
    - min_run_time    : Minimum job run time (in minutes) before a runner
                        is eligible for scale-down.
    - instance_types  : Allowed EC2 instance types for runners in this pool.
    - pool_config     : List of pool size schedules (size + cron expression
                        and optional time zone) controlling baseline capacity.
    - runner_user     : OS user under which the GitHub runner process runs.
    - enable_userdata : Whether the module should inject its standard
                        userdata to configure the runner VM.
    - instance_target_capacity_type: EC2 capacity type to use (spot or
                        on-demand).
    - block_device_mappings: EBS volume configuration for the runner
                        instances, including size, type, encryption, and KMS.
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
      scale_set_name               = string
      scale_set_type               = string
      container_actions_runner     = string
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
    - container_actions_runner    : Container image used for the ARC runner.
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
