locals {
  # Project-wide settings (i.e. global across the various AWS accounts used in
  # the overall repo/project).
  global_data  = read_terragrunt_config(find_in_parent_folders("_global_settings/_global.hcl"))
  group_email  = local.global_data.locals.group_email
  team_name    = local.global_data.locals.team_name
  product_name = local.global_data.locals.product_name

  # Environment-wide settings.
  env_data            = read_terragrunt_config(find_in_parent_folders("_environment_wide_settings/_environment.hcl"))
  env_for_tags        = local.env_data.locals.env_for_tags
  default_aws_region  = local.env_data.locals.default_aws_region
  default_aws_profile = local.env_data.locals.default_aws_profile

  tags = {
    TeamName         = local.team_name
    TechnicalContact = local.group_email
    SecurityContact  = local.group_email
  }

  default_tags = {
    # Common tags we propagate project-wide.
    ApplicationName   = local.product_name
    Environment       = local.env_for_tags
    ResourceOwner     = local.team_name
    ProductFamilyName = local.product_name
    IntendedPublic    = "No"
    LastRevalidatedBy = "Terraform"
    # Don't make this dynamic or it changes every apply.
    LastRevalidatedAt = "2025-05-15"
    # Additional security tags added at a later date by security/asset-tagging
    # team.
  }
}

inputs = {
  aws_profile = local.default_aws_profile
  aws_region  = local.default_aws_region

  splunk_conf = {
    splunk_cloud = "<ADD YOUR VALUE>" # e.g., example-org.splunkcloud.com
    acl = {
      app     = "<ADD YOUR VALUE>" # e.g., "search_app_generic"
      owner   = "<ADD YOUR VALUE>" # e.g., "generic-user"
      sharing = "global"
      read    = ["*"]
      write = [
        "<ADD YOUR VALUE>" # e.g., "generic-user-role"
      ]
    }
    index = "forge-index"
  }
  default_tags = local.default_tags
}
