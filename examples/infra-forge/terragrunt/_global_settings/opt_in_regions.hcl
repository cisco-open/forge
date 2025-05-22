locals {
  # Project-wide settings (i.e. global across the various AWS accounts used in
  # the overall repo/project).
  global_data  = read_terragrunt_config(find_in_parent_folders("_global_settings/_global.hcl"))
  group_email  = local.global_data.locals.group_email
  project_name = local.global_data.locals.project_name

  # Environment-wide settings.
  env_data = read_terragrunt_config(find_in_parent_folders("_environment_wide_settings/_environment.hcl"))
  # Default AWS profile and region. Typically used when deciding on
  # master/replica setups, such as auto-replication of secrets, databases, etc.
  default_aws_region  = local.env_data.locals.default_aws_region
  default_aws_profile = local.env_data.locals.default_aws_profile

  opt_in_regions_data = read_terragrunt_config(find_in_parent_folders("opt_in_regions/config.hcl"))
}

inputs = {
  # Common values re-used throughout sub-modules. These are also used in things
  # like logs, determining which S3 buckets and/or paths to use for storing
  # build artifacts, etc.

  aws_profile = local.default_aws_profile

  # Let's centralize this into a common region.
  aws_region = local.env_data.locals.default_aws_region
  # Configuration for Forge runners.
  opt_in_regions = local.opt_in_regions_data.locals.opt_in_regions
}
