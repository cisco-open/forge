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

  splunk_cloud_data = read_terragrunt_config(find_in_parent_folders("splunk_cloud/config.hcl"))

  log_group_name_prefixes = [
    "/github-self-hosted-runners/"
  ]

  splunk_cloud_data_manager = {
    splunk_cloud = "<your instance>.splunkcloud.com"
    cloudformation_s3_config = {
      bucket = "${local.aws_account_id}-short-term-storage"
      key    = "cicd_artifacts/cf-templates/"
      region = local.default_aws_region
    }
    index_name  = "forge-prod-index"
    input_name  = "forge-ccwl-forgecicd-${local.splunk_cloud_data.locals.env}"
    source_type = "forgecicd"

    log_group_name_prefixes = flatten([
      for region in local.splunk_cloud_data.locals.regions : [
        for log_group_name_prefix in local.log_group_name_prefixes : {
          region                = region
          log_group_name_prefix = log_group_name_prefix
        }
      ]
    ])
  }

  extra_tags = {
    TeamName = local.team_name
  }

  default_tags = {
    ApplicationName = local.product_name
    Environment     = local.env_for_tags
    ResourceOwner   = local.team_name
  }

  tenant_paths = split("\n", trimspace(run_cmd(
    "find", "../regions", "-type", "d", "-path", "*/tenants/*",
    "!", "-path", "*/.*",
    "!", "-name", "_*"
  )))
}

dependencies {
  paths = local.tenant_paths
}

inputs = {
  aws_account_id = local.aws_account_id
  aws_profile    = local.default_aws_profile
  aws_region     = local.default_aws_region

  splunk_cloud             = "https://${local.splunk_cloud_data_manager.splunk_cloud}"
  cloudformation_s3_config = local.splunk_cloud_data_manager.cloudformation_s3_config
  custom_cloudwatch_log_groups_config = {
    enabled                 = true
    name                    = local.splunk_cloud_data_manager.input_name
    index                   = local.splunk_cloud_data_manager.index_name
    source_type             = local.splunk_cloud_data_manager.source_type
    log_group_name_prefixes = local.splunk_cloud_data_manager.log_group_name_prefixes
  }

  tags     = local.default_tags
  all_tags = merge(local.extra_tags, local.default_tags)
}
