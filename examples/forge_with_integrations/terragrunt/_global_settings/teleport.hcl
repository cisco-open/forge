locals {
  # Project-wide settings (i.e. global across the various AWS accounts used in
  # the overall repo/project).
  global_data  = read_terragrunt_config(find_in_parent_folders("_global_settings/_global.hcl"))
  group_email  = local.global_data.locals.group_email
  team_name    = local.global_data.locals.team_name
  product_name = local.global_data.locals.product_name

  # Environment-wide settings.
  env_data            = read_terragrunt_config(find_in_parent_folders("_environment_wide_settings/_environment.hcl"))
  env_for_tags        = local.env_data.locals.env_for_tags
  default_aws_profile = local.env_data.locals.default_aws_profile

  # Region-wide settings.
  region_data = read_terragrunt_config(find_in_parent_folders("_region_wide_settings/_region.hcl"))
  region      = local.region_data.locals.region_aws

  teleport_data = read_terragrunt_config(find_in_parent_folders("teleport/config.hcl"))

  tenant_paths = split("\n", trimspace(run_cmd(
    "find", "../tenants", "-mindepth", "1", "-maxdepth", "1", "-type", "d",
    "!", "-path", "*/.*",
    "!", "-name", "_*"
  )))

  tags = {
    TeamName         = local.team_name
    TechnicalContact = local.group_email
    SecurityContact  = local.group_email
  }

  default_tags = {
    # Common tags we propagate project-wide.
    ApplicationName   = local.product_name
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

dependencies {
  paths = local.tenant_paths
}

inputs = {
  aws_profile = local.default_aws_profile
  aws_region  = local.region

  tenant_prefix   = local.teleport_data.locals.tenant_prefix
  tenants         = local.teleport_data.locals.tenants
  teleport_config = local.teleport_data.locals.teleport_config

  tags         = local.tags
  default_tags = local.default_tags
}
