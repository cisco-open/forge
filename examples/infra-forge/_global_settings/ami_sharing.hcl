locals {
  # Project-wide settings (i.e. global across the various AWS accounts used in
  # the overall repo/project).
  global_data  = read_terragrunt_config(find_in_parent_folders("_global_settings/_global.hcl"))
  group_email  = local.global_data.locals.group_email
  project_name = local.global_data.locals.project_name

  # Environment-wide settings.
  env_data            = read_terragrunt_config(find_in_parent_folders("_environment_wide_settings/_environment.hcl"))
  default_aws_profile = local.env_data.locals.default_aws_profile

  # Region-wide settings.
  region_data = read_terragrunt_config(find_in_parent_folders("_region_wide_settings/_region.hcl"))
  region      = local.region_data.locals.region_aws

  ami_sharing_data = read_terragrunt_config(find_in_parent_folders("ami_sharing/config.hcl"))
}

inputs = {

  aws_profile = local.default_aws_profile

  aws_region      = local.region
  account_ids     = local.ami_sharing_data.locals.account_ids
  ami_name_filter = local.ami_sharing_data.locals.ami_name_filter
}
