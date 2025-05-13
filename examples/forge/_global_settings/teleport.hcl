locals {
  # Project-wide settings (i.e. global across the various AWS accounts used in
  # the overall repo/project).
  global_data  = read_terragrunt_config(find_in_parent_folders("_global_settings/_global.hcl"))
  team_name    = local.global_data.locals.team_name
  product_name = local.global_data.locals.product_name

  # Environment-wide settings.
  env_data            = read_terragrunt_config(find_in_parent_folders("_environment_wide_settings/_environment.hcl"))
  env_for_tags        = local.env_data.locals.env_for_tags
  default_aws_profile = local.env_data.locals.default_aws_profile
  aws_account_id      = local.env_data.locals.aws_account_id

  # Region-wide settings.
  region_data = read_terragrunt_config(find_in_parent_folders("_region_wide_settings/_region.hcl"))
  region      = local.region_data.locals.region_aws

  teleport_data = read_terragrunt_config(find_in_parent_folders("teleport/config.hcl"))
}

inputs = {
  aws_account_id = local.aws_account_id
  aws_profile    = local.default_aws_profile

  # Let's centralize this into a common region.
  aws_region = local.region

  tenant_prefix   = local.teleport_data.locals.tenant_prefix
  tenants         = local.teleport_data.locals.tenants
  teleport_config = local.teleport_data.locals.teleport_config

  tags = {
    TeamName = local.team_name
  }

  default_tags = {
    # Common tags we propagate project-wide.
    ApplicationName = local.product_name
    Environment     = local.env_for_tags
    ResourceOwner   = local.team_name
  }
}
