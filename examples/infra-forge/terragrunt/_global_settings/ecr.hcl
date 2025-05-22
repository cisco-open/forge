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
}

inputs = {
  # Common values re-used throughout sub-modules. These are also used in things
  # like logs, determining which S3 buckets and/or paths to use for storing
  # build artifacts, etc.

  aws_profile = local.default_aws_profile

  aws_region = local.region
}
