locals {
  # Global settings.
  global_data  = read_terragrunt_config(find_in_parent_folders("_global_settings/_global.hcl"))
  team_name    = local.global_data.locals.team_name
  product_name = local.global_data.locals.product_name
  project_name = local.global_data.locals.project_name

  # Environment settings.
  env_data            = read_terragrunt_config(find_in_parent_folders("_environment_wide_settings/_environment.hcl"))
  default_aws_profile = local.env_data.locals.default_aws_profile

  # Region settings.
  region_data = read_terragrunt_config(find_in_parent_folders("_region_wide_settings/_region.hcl"))
  region      = local.region_data.locals.region_aws

  default_tags = {
    ApplicationName   = local.project_name
    ResourceOwner     = local.team_name
    ProductFamilyName = local.product_name
    IntendedPublic    = "No"
    LastRevalidatedBy = "Terraform"
    LastRevalidatedAt = "2025-05-15"
  }

  opencost_settings_data = read_terragrunt_config(find_in_parent_folders("splunk_opencost_eks/config.hcl"))
}

dependencies {
  paths = [
    find_in_parent_folders("splunk_otel_eks")
  ]
}

inputs = {
  # Core environment.
  aws_profile = local.default_aws_profile
  aws_region  = local.region

  # OpenCost EKS configuration.
  cluster_name = local.opencost_settings_data.locals.cluster_name

  # Misc.
  default_tags = local.default_tags
}
