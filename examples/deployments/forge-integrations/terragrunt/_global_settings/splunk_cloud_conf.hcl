locals {
  # ─────────────────────────────────────────────────────────────────────────────
  # Global Settings
  # ─────────────────────────────────────────────────────────────────────────────
  global_data  = read_terragrunt_config(find_in_parent_folders("_global_settings/_global.hcl"))
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
  default_tags = {
    ApplicationName   = local.project_name
    ResourceOwner     = local.team_name
    ProductFamilyName = local.product_name
    IntendedPublic    = "No"
    LastRevalidatedBy = "Terraform"
    LastRevalidatedAt = "2025-05-15"
  }
}

inputs = {
  # Core Environment
  aws_profile = local.default_aws_profile
  aws_region  = local.default_aws_region

  # Splunk Cloud Configuration
  splunk_conf = {
    splunk_cloud = "example-org.splunkcloud.com" # <REPLACE WITH YOUR VALUE>
    acl = {
      app     = "search_app_generic" # <REPLACE WITH YOUR VALUE>
      owner   = "forge-generic-user" # <REPLACE WITH YOUR VALUE>
      sharing = "global"             # <REPLACE WITH YOUR VALUE>
      read    = ["*"]                # <REPLACE WITH YOUR VALUE>
      write = [
        "forge-generic-user-role" # <REPLACE WITH YOUR VALUE>
      ]
    }
    index = "forge-index" # <REPLACE WITH YOUR VALUE>
  }

  # Misc
  default_tags = local.default_tags
}
