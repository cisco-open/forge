locals {
  # Project-wide settings (i.e. global across the various AWS accounts used in
  # the overall repo/project).
  global_data  = read_terragrunt_config(find_in_parent_folders("_global_settings/_global.hcl"))
  group_email  = local.global_data.locals.group_email
  project_name = local.global_data.locals.project_name

  # Default AWS profile and region. Typically used when deciding on
  # master/replica setups, such as auto-replication of secrets, databases, etc.
  default_aws_profile = local.env_data.locals.default_aws_profile
  aws_account_id      = local.env_data.locals.aws_account_id

  budget_data = read_terragrunt_config(find_in_parent_folders("budget/config.hcl"))
}

inputs = {
  # Common values re-used throughout sub-modules. These are also used in things
  # like logs, determining which S3 buckets and/or paths to use for storing
  # build artifacts, etc.
  project_name   = local.project_name
  aws_profile    = local.default_aws_profile
  aws_account_id = local.aws_account_id

  sl_aws_account_name = local.env_data.locals.sl_aws_account_name

  # Let's centralize this into a common region.
  aws_region = local.env_data.locals.default_aws_region
  # Configuration for Forge runners.
  aws_budget = local.budget_data.locals.aws_budget
}
