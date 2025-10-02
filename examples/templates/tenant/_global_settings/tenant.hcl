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
  env            = local.env_name
  aws_account_id = local.aws_account_id
  aws_profile    = local.default_aws_profile
  aws_region     = local.region

  # Networking
  vpc_id            = local.runner_settings_data.locals.vpc_id
  subnet_ids        = local.runner_settings_data.locals.subnet_ids
  lambda_subnet_ids = local.runner_settings_data.locals.lambda_subnet_ids

  # Runners (EC2/ARC)
  ec2_runner_specs    = local.runner_settings_data.locals.ec2_runner_specs
  arc_cluster_name    = local.runner_settings_data.locals.arc_cluster_name
  arc_runner_specs    = local.runner_settings_data.locals.arc_runner_specs
  migrate_arc_cluster = local.runner_settings_data.locals.migrate_arc_cluster

  # GitHub Settings
  ghes_url             = local.runner_settings_data.locals.ghes_url
  ghes_org             = local.runner_settings_data.locals.ghes_org
  repository_selection = local.runner_settings_data.locals.repository_selection
  runner_group_name    = local.runner_settings_data.locals.runner_group_name
  github_webhook_relay = local.runner_settings_data.locals.github_webhook_relay

  # Misc
  deployment_config         = local.runner_settings_data.locals.deployment_config
  log_level                 = local.runner_settings_data.locals.log_level
  logging_retention_in_days = local.runner_settings_data.locals.logging_retention_in_days
  tenant                    = local.tenant
  tags                      = local.tags
  default_tags              = local.default_tags
}
