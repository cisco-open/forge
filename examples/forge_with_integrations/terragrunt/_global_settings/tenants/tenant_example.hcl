locals {
  # Project-wide settings (i.e. global across the various AWS accounts used in
  # the overall repo/project).
  global_data  = read_terragrunt_config(find_in_parent_folders("_global_settings/_global.hcl"))
  group_email  = local.global_data.locals.group_email
  team_name    = local.global_data.locals.team_name
  product_name = local.global_data.locals.product_name
  project_name = local.global_data.locals.project_name

  # Environment-wide settings.
  env_data            = read_terragrunt_config(find_in_parent_folders("_environment_wide_settings/_environment.hcl"))
  env_name            = local.env_data.locals.env
  env_for_tags        = local.env_data.locals.env_for_tags
  default_aws_region  = local.env_data.locals.default_aws_region
  default_aws_profile = local.env_data.locals.default_aws_profile
  aws_account_id      = local.env_data.locals.aws_account_id

  # Region-wide settings.
  region_data = read_terragrunt_config(find_in_parent_folders("_region_wide_settings/_region.hcl"))
  region      = local.region_data.locals.region_aws

  runner_settings_data = read_terragrunt_config(find_in_parent_folders("tenant_example/runner_settings.hcl"))
  tenant               = local.runner_settings_data.locals.tenant

  tags = {
    TeamName                = local.team_name
    TechnicalContact        = local.group_email
    SecurityContact         = local.group_email
    TenantName              = local.tenant.name
    ForgeCICDTenantName     = local.tenant.name
    TeleportTenantName      = local.tenant.teleport.tenant_name
    TenantVpcAlias          = local.tenant.vpc_alias
    ForgeCICDTenantVpcAlias = local.tenant.name
  }

  default_tags = {
    # Common tags we propagate project-wide.
    ApplicationName   = "${local.project_name}-${local.tenant.name}-${local.tenant.region_alias}-${local.tenant.vpc_alias}"
    Environment       = local.env_for_tags
    ResourceOwner     = local.team_name
    ProductFamilyName = local.product_name
    IntendedPublic    = "No"
    LastRevalidatedBy = "Terraform"
    # Don't make this dynamic or it changes every apply.
    LastRevalidatedAt = "2025-05-15"
    # Additional security tags added at a later date by security/asset-tagging
    # team.
  }
}

inputs = {
  env            = local.env_name
  aws_account_id = local.aws_account_id
  aws_profile    = local.default_aws_profile
  aws_region     = local.region

  lambda_subnet_ids = local.runner_settings_data.locals.lambda_subnet_ids
  vpc_id            = local.runner_settings_data.locals.vpc_id
  subnet_ids        = local.runner_settings_data.locals.subnet_ids

  ec2_runner_specs  = local.runner_settings_data.locals.ec2_runner_specs
  ghes_url          = local.runner_settings_data.locals.ghes_url
  ghes_org          = local.runner_settings_data.locals.ghes_org
  tenant            = local.runner_settings_data.locals.tenant
  runner_group_name = local.runner_settings_data.locals.runner_group_name
  log_level         = local.runner_settings_data.locals.log_level

  arc_cluster_name = local.runner_settings_data.locals.arc_cluster_name
  arc_runner_specs = local.runner_settings_data.locals.arc_runner_specs
  tags             = local.tags
  default_tags     = local.default_tags
}
