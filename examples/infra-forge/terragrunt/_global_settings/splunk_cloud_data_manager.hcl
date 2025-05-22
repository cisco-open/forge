locals {
  # Environment-wide settings.
  env_data     = read_terragrunt_config(find_in_parent_folders("_environment_wide_settings/_environment.hcl"))
  extra_tags   = local.env_data.locals.extra_tags
  default_tags = local.env_data.locals.default_tags

  # Default AWS profile and region. Typically used when deciding on
  # master/replica setups, such as auto-replication of secrets, databases, etc.
  default_aws_region  = local.env_data.locals.default_aws_region
  default_aws_profile = local.env_data.locals.default_aws_profile
  aws_account_id      = local.env_data.locals.aws_account_id

  splunk_cloud = read_terragrunt_config(find_in_parent_folders("splunk_cloud_data_manager/config.hcl"))
}

inputs = {
  # Common values re-used throughout sub-modules. These are also used in things
  # like logs, determining which S3 buckets and/or paths to use for storing
  # build artifacts, etc.
  aws_profile    = local.default_aws_profile
  aws_account_id = local.aws_account_id
  aws_region     = local.default_aws_region

  tags     = local.default_tags
  all_tags = merge(local.extra_tags, local.default_tags)

  splunk_cloud             = local.splunk_cloud.locals.splunk_cloud
  cloudformation_s3_config = local.splunk_cloud.locals.cloudformation_s3_config

  cloudwatch_log_groups_config = local.splunk_cloud.locals.cloudwatch_log_groups_config
  security_metadata_config     = local.splunk_cloud.locals.security_metadata_config
}
