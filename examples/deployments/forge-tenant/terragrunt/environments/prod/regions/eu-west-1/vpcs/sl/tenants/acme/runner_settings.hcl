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
  lambda_subnet_ids = include.vpc.locals.lambda_subnet_ids
  vpc_id            = include.vpc.locals.vpc_id
  subnet_ids        = include.vpc.locals.subnet_ids

  region_alias      = include.region.locals.region_alias
  vpc_alias         = include.vpc.locals.vpc_alias
  env_name          = include.env.locals.env
  runner_group_name = "${local.tenant_name}-${local.region_alias}-${local.vpc_alias}-${include.env.locals.runner_group_name_suffix}"

  # Tenant
  tenant_name = basename(get_terragrunt_dir())

  deployment_config = {
    prefix        = "${local.tenant_name}-${local.region_alias}-${local.vpc_alias}"
    secret_suffix = local.vpc_alias
  }

  log_level = "info"

  logging_retention_in_days = 3

  # Load and parse runner specs YAML once
  runner_specs_raw = yamldecode(file("config.yaml"))

  # GitHub App settings
  ghes_url             = local.runner_specs_raw.gh_config.ghes_url
  ghes_org             = local.runner_specs_raw.gh_config.ghes_org
  repository_selection = local.runner_specs_raw.gh_config.repository_selection
  github_webhook_relay = local.runner_specs_raw.gh_config.github_webhook_relay

  tenant = {
    name                = local.tenant_name
    iam_roles_to_assume = local.runner_specs_raw.tenant.iam_roles_to_assume
    ecr_registries      = local.runner_specs_raw.tenant.ecr_registries
  }

  ec2_runner_specs = {
    for size, spec in local.runner_specs_raw.ec2_runner_specs :
    size => {
      ami_filter = {
        name  = [spec.ami_name],
        state = ["available"],
      }
      ami_owners          = [spec.ami_owner]
      ami_kms_key_arn     = spec.ami_kms_key_arn
      runner_os           = spec.runner_os
      runner_architecture = spec.runner_architecture
      runner_labels = [
        "type:${spec.type}",
        "self-hosted",
        spec.runner_architecture,
        "env:ops-${include.env.locals.env}",
      ]
      extra_labels = [
        "rgn:${local.region_alias}",
        "vpc:${local.vpc_alias}",
        "tnt:${local.tenant_name}",
      ]
      enable_userdata               = true
      runner_user                   = "ubuntu"
      instance_target_capacity_type = "on-demand"
      min_run_time                  = 30
      max_instances                 = spec.max_instances
      instance_types                = spec.instance_types
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
      pool_config = spec.pool_config
    }
  }
  arc_cluster_name    = local.runner_specs_raw.arc_cluster_name
  migrate_arc_cluster = local.runner_specs_raw.migrate_arc_cluster

  arc_runner_specs = {
    for size, spec in local.runner_specs_raw.arc_runner_specs :
    size => {
      runner_size                  = spec.runner_size
      scale_set_name               = spec.scale_set_name
      scale_set_type               = spec.scale_set_type
      container_actions_runner     = spec.container_actions_runner
      container_requests_cpu       = spec.container_requests_cpu
      container_requests_memory    = spec.container_requests_memory
      container_limits_cpu         = spec.container_limits_cpu
      container_limits_memory      = spec.container_limits_memory
      volume_requests_storage_type = spec.volume_requests_storage_type
      volume_requests_storage_size = spec.volume_requests_storage_size
    }
  }
}
