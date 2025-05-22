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
  aws_account_id      = local.env_data.locals.aws_account_id

  splunk_cloud = read_terragrunt_config(find_in_parent_folders("splunk_cloud_data_manager_deps/config.hcl"))
}

inputs = {

  aws_profile    = local.default_aws_profile
  aws_account_id = local.aws_account_id

  aws_region   = local.default_aws_region
  splunk_cloud = local.splunk_cloud.locals.splunk_cloud
}
