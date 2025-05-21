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
  # GitHub App settings
  ghes_url = "<ADD YOUR VALUE>" # For gitHub Enterprise Server URL
  ghes_org = "<ADD YOUR VALUE>"

  # Aliases
  region_alias = include.region.locals.region_alias
  vpc_alias    = include.vpc.locals.vpc_alias

  # Tenant settings
  tenant_name       = "forge"
  runner_group_name = "${local.tenant_name}-${local.region_alias}-${local.vpc_alias}-${include.env.locals.runner_group_name_suffix}"
  log_level         = "info"

  # Runner labels
  runner_label_self_hosted  = "self-hosted"
  runner_label_architecture = "x64"
  runner_label_env          = "env:ops-${include.env.locals.env}"
  runner_label_region       = "aws-region:${include.region.locals.region_aws}"
  runner_label_vpc_type     = "vpc-type:${local.vpc_alias}"
  runner_label_tenant_name  = "tenant:${local.tenant_name}"

  # VPC settings
  lambda_subnet_ids = include.vpc.locals.lambda_subnet_ids
  vpc_id            = include.vpc.locals.vpc_id
  subnet_ids        = include.vpc.locals.subnet_ids

  # Tenant configuration
  tenant = {
    name = local.tenant_name
    teleport = {
      tenant_name = "forge"
    }
    region_alias = local.region_alias
    vpc_alias    = local.vpc_alias
    iam_roles_to_assume = [
      "<ADD YOUR VALUE>" # e.g., "arn:aws:iam::123456789012:role/role_for_forge_runners"
    ]
    ecr_registries = [
      "<ADD YOUR VALUE>" # e.g., "123456789012.dkr.ecr.eu-west-1.amazonaws.com"
    ]
  }

  # AMI settings for GitHub runners
  ami_filter = {
    name  = ["<ADD YOUR VALUE>"] # e.g., "forge-gh-runner-v*"
    state = ["available"]
  }
  ami_owner = "<ADD YOUR VALUE>" # e.g., "123456789012"

  # Runner specifications
  ec2_runner_specs = {
    "small" = {
      ami_filter      = local.ami_filter
      ami_owners      = [local.ami_owner]
      ami_kms_key_arn = ""
      aws_budget = {
        budget_limit = 500
      }
      runner_labels = [
        "type:small",
        local.runner_label_env,
        local.runner_label_self_hosted,
        local.runner_label_architecture,
      ]
      extra_labels = [
        local.runner_label_region,
        local.runner_label_vpc_type,
        local.runner_label_tenant_name,
      ]
      max_instances = 1
      min_run_time  = 30
      instance_types = [
        "t2.small", "t2.medium", "t2.large",
        "t3.small", "t3.medium", "t3.large",
      ]
      pool_config = [
      ]
      enable_userdata               = true
      runner_user                   = "ubuntu"
      instance_target_capacity_type = "on-demand"
      block_device_mappings = [{
        delete_on_termination = true
        device_name           = "/dev/sda1"
        encrypted             = true
        iops                  = null
        kms_key_id            = null
        snapshot_id           = null
        throughput            = null
        volume_size           = 80
        volume_type           = "gp3"
      }]
    },
    "standard" = {
      ami_filter      = local.ami_filter
      ami_owners      = [local.ami_owner]
      ami_kms_key_arn = ""
      aws_budget = {
        budget_limit = 500
      }
      runner_labels = [
        "type:standard",
        local.runner_label_env,
        local.runner_label_self_hosted,
        local.runner_label_architecture,
      ]
      extra_labels = [
        local.runner_label_region,
        local.runner_label_vpc_type,
        local.runner_label_tenant_name,
      ]
      max_instances = 10
      min_run_time  = 30
      instance_types = [
        "t3.medium", "t3.large",
        "t3.xlarge", "t3.2xlarge", "m5.large", "m5.xlarge",
      ]
      pool_config = [
      ]
      enable_userdata               = true
      runner_user                   = "ubuntu"
      instance_target_capacity_type = "on-demand"
      block_device_mappings = [{
        delete_on_termination = true
        device_name           = "/dev/sda1"
        encrypted             = true
        iops                  = null
        kms_key_id            = null
        snapshot_id           = null
        throughput            = null
        volume_size           = 80
        volume_type           = "gp3"
      }]
    },
    "large" = {
      ami_filter      = local.ami_filter
      ami_owners      = [local.ami_owner]
      ami_kms_key_arn = ""
      aws_budget = {
        budget_limit = 500
      }
      runner_labels = [
        "type:large",
        local.runner_label_env,
        local.runner_label_self_hosted,
        local.runner_label_architecture,
      ]
      extra_labels = [
        local.runner_label_region,
        local.runner_label_vpc_type,
        local.runner_label_tenant_name,
      ]
      max_instances = 1
      min_run_time  = 30
      instance_types = [
        "c6i.8xlarge", "c5.9xlarge", "c5.12xlarge",
        "c6i.12xlarge", "c6i.16xlarge"
      ]
      pool_config = [
      ]
      enable_userdata               = true
      runner_user                   = "ubuntu"
      instance_target_capacity_type = "on-demand"
      block_device_mappings = [{
        delete_on_termination = true
        device_name           = "/dev/sda1"
        encrypted             = true
        iops                  = null
        kms_key_id            = null
        snapshot_id           = null
        throughput            = null
        volume_size           = 80
        volume_type           = "gp3"
      }]
    },
  }

  arc_cluster_name = "forge-euw1-prod"

  arc_runner_specs = {
    "dependabot" = {
      runner_size = {
        max_runners = 100
        min_runners = 1
      }
      scale_set_name            = "dependabot"
      scale_set_type            = "dind"
      container_actions_runner  = "ghcr.io/actions/actions-runner:sha256-e03b4550955d539604233352ba27cd095a880b906400bb9283f1ee4b061e21bb"
      container_requests_cpu    = "500m"
      container_requests_memory = "1Gi"
      container_limits_cpu      = "1"
      container_limits_memory   = "2Gi"
    }
    "dind" = {
      runner_size = {
        max_runners = 100
        min_runners = 1
      }
      scale_set_name            = "dind"
      scale_set_type            = "dind"
      container_actions_runner  = "ghcr.io/actions/actions-runner:sha256-e03b4550955d539604233352ba27cd095a880b906400bb9283f1ee4b061e21bb"
      container_requests_cpu    = "500m"
      container_requests_memory = "1Gi"
      container_limits_cpu      = "1"
      container_limits_memory   = "2Gi"
    }
    "k8s" = {
      runner_size = {
        max_runners = 100
        min_runners = 1
      }
      scale_set_name            = "k8s"
      scale_set_type            = "k8s"
      container_actions_runner  = "ghcr.io/actions/actions-runner:sha256-e03b4550955d539604233352ba27cd095a880b906400bb9283f1ee4b061e21bb"
      container_requests_cpu    = "500m"
      container_requests_memory = "1Gi"
      container_limits_cpu      = "1"
      container_limits_memory   = "2Gi"
    }
  }
}
