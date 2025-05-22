locals {
  # Project-wide settings (i.e. global across the various AWS accounts used in
  # the overall repo/project).
  global_data  = read_terragrunt_config(find_in_parent_folders("_global_settings/_global.hcl"))
  group_email  = local.global_data.locals.group_email
  project_name = local.global_data.locals.project_name

  # Environment-wide settings.
  env_data            = read_terragrunt_config(find_in_parent_folders("_environment_wide_settings/_environment.hcl"))
  default_aws_profile = local.env_data.locals.default_aws_profile
  aws_account_id      = local.env_data.locals.aws_account_id
}

inputs = {
  # Common values re-used throughout sub-modules. These are also used in things
  # like logs, determining which S3 buckets and/or paths to use for storing
  # build artifacts, etc.
  project_name   = local.project_name
  aws_profile    = local.default_aws_profile
  aws_account_id = local.aws_account_id

  aws_region = local.default_aws_region
}
