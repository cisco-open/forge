locals {
  # Project-wide settings (i.e. global across the various AWS accounts used in
  # the overall repo/project).
  global_data  = read_terragrunt_config(find_in_parent_folders("_global_settings/_global.hcl"))
  group_email  = local.global_data.locals.group_email
  team_name    = local.global_data.locals.team_name
  project_name = local.global_data.locals.project_name
  product_name = local.global_data.locals.product_name

  # Environment-wide settings.
  env_data     = read_terragrunt_config(find_in_parent_folders("_environment_wide_settings/_environment.hcl"))
  env_name     = local.env_data.locals.env
  env_for_tags = local.env_data.locals.env_for_tags
  # Default AWS profile and region. Typically used when deciding on
  # master/replica setups, such as auto-replication of secrets, databases, etc.
  default_aws_region  = local.env_data.locals.default_aws_region
  default_aws_profile = local.env_data.locals.default_aws_profile
  aws_account_id      = local.env_data.locals.aws_account_id
  # DRY re-use of back-end configuration across modules.
  remote_state_config = local.env_data.locals.remote_state_config

}

inputs = {
  aws_profile = local.default_aws_profile
  aws_region  = local.default_aws_region

  splunk_conf = {
    splunk_cloud = "<your instance>.splunkcloud.com"
    extractions = {
      acl = {
        app     = "<your splunk app>"
        owner   = "<your splunk user>"
        sharing = "app"
        read    = ["*"]
        write   = ["<role name>"]
      }
    }
  }

  default_tags = {
    # Common tags we propagate project-wide.
    ApplicationName = local.product_name
    Environment     = local.env_for_tags
    ResourceOwner   = local.team_name
  }
}
