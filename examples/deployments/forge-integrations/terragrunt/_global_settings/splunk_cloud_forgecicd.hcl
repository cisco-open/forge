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

  splunk_cloud_data = read_terragrunt_config(find_in_parent_folders("splunk_cloud_forgecicd/config.hcl"))

  log_group_name_prefixes = [
    "/github-self-hosted-runners/"
  ]

  splunk_cloud_data_manager = {
    splunk_cloud = "example-org.splunkcloud.com" # <REPLACE WITH YOUR VALUE>
    cloudformation_s3_config = {
      bucket = "${local.aws_account_id}-short-term-storage" # <REPLACE WITH YOUR VALUE>
      key    = "cicd_artifacts/cf-templates/"
      region = local.default_aws_region
    }
    index_name  = "forge-index"                                                # <REPLACE WITH YOUR VALUE>
    input_name  = "forge-ccwl-forgecicd-${local.splunk_cloud_data.locals.env}" # <REPLACE WITH YOUR VALUE>
    source_type = "forgecicd"                                                  # <REPLACE WITH YOUR VALUE>

    log_group_name_prefixes = flatten([
      for region in local.splunk_cloud_data.locals.regions : [
        for log_group_name_prefix in local.log_group_name_prefixes : {
          region                = region
          log_group_name_prefix = log_group_name_prefix
        }
      ]
    ])
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

  tags         = local.tags
  default_tags = local.default_tags
}
