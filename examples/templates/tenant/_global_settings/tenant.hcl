locals {
  # ─────────────────────────────────────────────────────────────────────────────
  # Global Settings
  # ─────────────────────────────────────────────────────────────────────────────
  global_data  = read_terragrunt_config(find_in_parent_folders("_global_settings/_global.hcl"))
  group_email  = local.global_data.locals.group_email
  team_name    = local.global_data.locals.team_name
  product_name = local.global_data.locals.product_name
  project_name = local.global_data.locals.project_name

  # ─────────────────────────────────────────────────────────────────────────────
  # Environment Settings
  # ─────────────────────────────────────────────────────────────────────────────
  env_data            = read_terragrunt_config(find_in_parent_folders("_environment_wide_settings/_environment.hcl"))
  env_name            = local.env_data.locals.env
  default_aws_region  = local.env_data.locals.default_aws_region
  default_aws_profile = local.env_data.locals.default_aws_profile
  aws_account_id      = local.env_data.locals.aws_account_id

  # ─────────────────────────────────────────────────────────────────────────────
  # Region Settings
  # ─────────────────────────────────────────────────────────────────────────────
  region_data = read_terragrunt_config(find_in_parent_folders("_region_wide_settings/_region.hcl"))
  region      = local.region_data.locals.region_aws

  # ─────────────────────────────────────────────────────────────────────────────
  # Tenant Settings
  # ─────────────────────────────────────────────────────────────────────────────
  runner_settings_data = read_terragrunt_config("runner_settings.hcl")
  tenant               = local.runner_settings_data.locals.tenant

  # ─────────────────────────────────────────────────────────────────────────────
  # Tags
  # ─────────────────────────────────────────────────────────────────────────────
  tags = {
    TenantName              = local.tenant.name
    ForgeCICDTenantName     = local.tenant.name
    ForgeCICDTenantVpcAlias = local.runner_settings_data.locals.vpc_alias
  }

  default_tags = {
    ApplicationName   = "${local.project_name}-${local.tenant.name}-${local.runner_settings_data.locals.region_alias}-${local.runner_settings_data.locals.vpc_alias}"
    ResourceOwner     = local.team_name
    ProductFamilyName = local.product_name
    IntendedPublic    = "No"
    LastRevalidatedBy = "Terraform"
    LastRevalidatedAt = "2025-05-15"
  }
}

inputs = {
  # Core Environment
  aws_profile = local.default_aws_profile
  aws_region  = local.region

  # Runners (EC2/ARC)
  ec2_deployment_specs = {
    lambda_subnet_ids = local.config.locals.lambda_subnet_ids
    subnet_ids        = local.config.locals.subnet_ids
    vpc_id            = local.config.locals.vpc_id
    runner_specs      = local.config.locals.ec2_runner_specs
  }

  arc_deployment_specs = {
    cluster_name    = local.config.locals.arc_cluster_name
    migrate_cluster = local.config.locals.migrate_arc_cluster
    runner_specs    = local.config.locals.arc_runner_specs
  }

  # Deployment Settings
  deployment_config = local.config.locals.deployment_config

  # Misc
  log_level                 = local.config.locals.log_level
  logging_retention_in_days = local.config.locals.logging_retention_in_days
  tags                      = local.tags
  default_tags              = local.default_tags
}
