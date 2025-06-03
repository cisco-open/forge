locals {
  # ─────────────────────────────────────────────────────────────────────────────
  # Global Settings
  # ─────────────────────────────────────────────────────────────────────────────
  global_data  = read_terragrunt_config(find_in_parent_folders("_global_settings/_global.hcl"))
  group_email  = local.global_data.locals.group_email
  team_name    = local.global_data.locals.team_name
  product_name = local.global_data.locals.product_name
  project_name = local.global_data.locals.project_name

  # ─────────────────────────────────────────────────────────────────────────────
  # Environment Settings
  # ─────────────────────────────────────────────────────────────────────────────
  env_data            = read_terragrunt_config(find_in_parent_folders("_environment_wide_settings/_environment.hcl"))
  default_aws_region  = local.env_data.locals.default_aws_region
  default_aws_profile = local.env_data.locals.default_aws_profile

  # ─────────────────────────────────────────────────────────────────────────────
  # Tags
  # ─────────────────────────────────────────────────────────────────────────────
  tags = {
    TeamName         = local.team_name
    TechnicalContact = local.group_email
    SecurityContact  = local.group_email
  }

  default_tags = {
    ApplicationName   = local.project_name
    ResourceOwner     = local.team_name
    ProductFamilyName = local.product_name
    IntendedPublic    = "No"
    LastRevalidatedBy = "Terraform"
    LastRevalidatedAt = "2025-05-15"
  }

  splunk_cloud = read_terragrunt_config(find_in_parent_folders("splunk_cloud_data_manager/config.hcl"))
}

inputs = {
  # Core Environment
  aws_account_id = local.aws_account_id
  aws_profile    = local.default_aws_profile
  aws_region     = local.default_aws_region

  # Splunk Cloud Configuration
  splunk_cloud             = local.splunk_cloud.locals.splunk_cloud
  cloudformation_s3_config = local.splunk_cloud.locals.cloudformation_s3_config

  # Splunk Cloud Data Manager Configuration
  cloudwatch_log_groups_config = local.splunk_cloud.locals.cloudwatch_log_groups_config
  security_metadata_config     = local.splunk_cloud.locals.security_metadata_config

  # Misc
  tags         = local.tags
  default_tags = local.default_tags
}
