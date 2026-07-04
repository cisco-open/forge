locals {
  global_data  = read_terragrunt_config(find_in_parent_folders("_global_settings/_global.hcl"))
  team_name    = local.global_data.locals.team_name
  product_name = local.global_data.locals.product_name
  project_name = local.global_data.locals.project_name

  env_data = read_terragrunt_config(find_in_parent_folders("_environment_wide_settings/_environment.hcl"))

  opt_in_regions_data = read_terragrunt_config(find_in_parent_folders("opt_in_regions/config.hcl"))

  default_tags = {
    ApplicationName   = local.project_name
    ResourceOwner     = local.team_name
    ProductFamilyName = local.product_name
    IntendedPublic    = "No"
    LastRevalidatedBy = "Terraform"
    LastRevalidatedAt = "2025-05-15"
  }
}

inputs = {
  aws_profile = local.env_data.locals.default_aws_profile
  aws_region  = local.env_data.locals.default_aws_region

  opt_in_regions = local.opt_in_regions_data.locals.opt_in_regions

  default_tags = local.default_tags
}
