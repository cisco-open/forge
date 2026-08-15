# Environment-wide settings.
include "env" {
  path   = find_in_parent_folders("_environment_wide_settings/_environment.hcl")
  expose = true
}

# Region-wide settings.
include "region" {
  path   = find_in_parent_folders("_region_wide_settings/_region.hcl")
  expose = true
}

# VPC-wide settings.
include "vpc" {
  path   = find_in_parent_folders("_vpc_wide_settings/_vpc.hcl")
  expose = true
}

locals {
  # VPC & region info from includes
  lambda_vpc_id     = include.vpc.locals.vpc_id
  lambda_subnet_ids = include.vpc.locals.lambda_subnet_ids
  vpc_id            = include.vpc.locals.vpc_id
  subnet_ids        = include.vpc.locals.subnet_ids

  region_alias      = include.region.locals.region_alias
  vpc_alias         = include.vpc.locals.vpc_alias
  env_name          = include.env.locals.env
  runner_group_name = "${local.tenant_name}-${local.region_alias}-${local.vpc_alias}-${include.env.locals.runner_group_name_suffix}"

  # Tenant
  tenant_name = basename(get_terragrunt_dir())

  log_level = "info"

  logging_retention_in_days = 3

  # Load and parse runner specs YAML once
  config = yamldecode(file("config.yml"))

  # GitHub App settings
  github_webhook_relay = local.config.gh_config.github_webhook_relay

  deployment_config = {
    deployment_prefix = "${local.tenant_name}-${local.region_alias}-${local.vpc_alias}"
    secret_suffix     = local.vpc_alias
    env               = local.env_name
    github_app        = local.config.gh_config.github_app
    tenant = {
      name                         = local.tenant_name
      iam_roles_to_assume          = local.config.tenant.iam_roles_to_assume
      ecr_registries               = local.config.tenant.ecr_registries
      github_logs_reader_role_arns = local.config.tenant.github_logs_reader_role_arns
    }
    github = {
      ghes_org             = local.config.gh_config.ghes_org
      ghes_url             = local.config.gh_config.ghes_url
      repository_selection = local.config.gh_config.repository_selection
      runner_group_name    = local.runner_group_name
    }
  }

  ec2_runner_specs = {
    for size, spec in local.config.ec2_runner_specs :
    size => {
      # Keep the former Forge v1 behavior explicit while adopting the v2 shape.
      runner = {
        os           = spec.runner_os
        architecture = spec.runner_architecture
        extra_labels = [
          "ec2",
          "rgn:${local.region_alias}",
          "vpc:${local.vpc_alias}",
          "tnt:${local.tenant_name}",
        ]
        group_name = local.runner_group_name
        run_as     = spec.runner_user
        ephemeral  = true
      }
      orchestration = {
        webhook = {
          runner = {
            maximum_count = spec.max_instances
          }
          github = {
            organization_runners = true
          }
          lambda = {
            scale_up = {
              job_queued_check_enabled = false
              event_source_mapping = {
                batch_size                         = try(spec.lambda_event_source_mapping_batch_size, 10)
                maximum_batching_window_in_seconds = try(spec.lambda_event_source_mapping_maximum_batching_window_in_seconds, 0)
              }
            }
            scale_down = {
              minimum_running_time_in_minutes = 30
            }
            pool = {
              config       = spec.pool_config
              runner_owner = local.config.gh_config.ghes_org
            }
          }
          queue = {
            delay_webhook_event            = 0
            job_queue_retention_in_seconds = 172800
            visibility_timeout_seconds     = 180
            redrive_build_queue = {
              enabled         = try(spec.redrive_build_queue.enabled, true)
              maxReceiveCount = try(spec.redrive_build_queue.maxReceiveCount, 10)
            }
          }
          matcherConfig = {
            labelMatchers = concat(
              [[
                "type:${spec.type}",
                "self-hosted",
                spec.runner_architecture,
                "env:ops-${include.env.locals.env}",
              ]],
              concat([
                for label_count in range(1, 5) : concat([
                  for start in range(0, 5 - label_count) : concat(
                    [
                      "type:${spec.type}",
                      "self-hosted",
                      spec.runner_architecture,
                      "env:ops-${include.env.locals.env}",
                    ],
                    slice([
                      "ec2",
                      "rgn:${local.region_alias}",
                      "vpc:${local.vpc_alias}",
                      "tnt:${local.tenant_name}",
                    ], start, start + label_count),
                  )
                ])
              ]...),
            )
            exactMatch             = true
            enableDynamicLabels    = try(spec.enable_dynamic_labels, false)
            awsDynamicLabelsPolicy = try(spec.aws_dynamic_labels_policy, null)
          }
        }
      }
      compute_provider = {
        ec2 = {
          metadata_options = {
            http_endpoint               = "enabled"
            http_put_response_hop_limit = 2
            http_tokens                 = "optional"
            instance_metadata_tags      = "enabled"
          }
          ami = {
            filter = {
              name  = [spec.ami_name]
              state = ["available"]
            }
            owners = [spec.ami_owner]
            kms_key = trimspace(spec.ami_kms_key_arn) == "" ? null : {
              arn = spec.ami_kms_key_arn
            }
          }
          create_service_linked_role_spot = true
          cloudwatch_agent = {
            enabled = true
          }
          binaries_syncer = {
            enabled = false
          }
          detailed_monitoring_enabled = true
          ssm_enabled                 = true
          user_data = {
            enabled     = true
            pre_install = "# No pre-install steps."
          }
          instance_target_capacity_type = "on-demand"
          instance_types                = spec.instance_types
          placement                     = try(spec.placement, null)
          license_specifications        = try(spec.license_specifications, null)
          use_dedicated_host            = try(spec.use_dedicated_host, false)
          vpc_id                        = try(spec.vpc_id, null)
          subnet_ids                    = try(spec.subnet_ids, null)
          scale_errors                  = try(spec.scale_errors, null)
          block_device_mappings = [{
            delete_on_termination = true
            device_name           = spec.volume.device_name
            encrypted             = true
            iops                  = spec.volume.iops
            kms_key_id            = null
            snapshot_id           = null
            throughput            = spec.volume.throughput
            volume_size           = spec.volume.size
            volume_type           = spec.volume.type
          }]
        }
      }
    }
  }

  arc_cluster_name    = local.config.arc_cluster_name
  migrate_arc_cluster = local.config.migrate_arc_cluster

  arc_runner_specs = {
    for size, spec in local.config.arc_runner_specs :
    size => {
      runner_size    = spec.runner_size
      scale_set_name = spec.scale_set_name
      scale_set_type = spec.scale_set_type
      scale_set_labels = [
        "${spec.scale_set_name}",
        "type:${spec.scale_set_type}",
        "self-hosted",
        "x64",
        "env:ops-${include.env.locals.env}",
        "arc",
        "rgn:${local.region_alias}",
        "vpc:${local.vpc_alias}",
        "tnt:${local.tenant_name}",
      ]
      container_images             = try(spec.container_images, {})
      container_requests_cpu       = spec.container_requests_cpu
      container_requests_memory    = spec.container_requests_memory
      container_limits_cpu         = spec.container_limits_cpu
      container_limits_memory      = spec.container_limits_memory
      volume_requests_storage_type = spec.volume_requests_storage_type
      volume_requests_storage_size = spec.volume_requests_storage_size
    }
  }
}
