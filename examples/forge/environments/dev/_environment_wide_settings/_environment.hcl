locals {
  # Project-wide global settings.
  global_settings = read_terragrunt_config(find_in_parent_folders("_global_settings/_global.hcl"))

  # Environment name.
  env = "dev"

  # Prefix used throughout various bits of code involving auth. Must only
  # contain letters, numbers, and hyphens (valid hostname characters).
  prefix = "dev"

  # Default region in which we store critical infra such as secrets, DynamoDB
  # tables, etc.
  default_aws_region = "eu-west-1"

  runner_group_name_suffix = "cicd-forge-dev"

  # Variant of environment name. Used for company-specific tagging (for
  # security and team-billing purposes). Can be "Prod" or "NonProd".
  env_for_tags = "NonProd"

  # AWS account associated with this environment.
  aws_account_id                          = "123456789012" # Replace with your AWS account ID
  sl_aws_account_name                     = "${local.global_settings.locals.sl_aws_account_prefix}-${local.env}"
  default_aws_profile                     = "${local.sl_aws_account_name}"
  default_aws_profile_with_default_region = "${local.sl_aws_account_name}-${local.default_aws_region}"

  # Sanitized values
  sanitized_project_name = replace(local.global_settings.locals.project_name, "_", "-")
  sanitized_git_org      = replace(local.global_settings.locals.git_org, "_", "-")

  # Default security tags.
  default_tags = {
    ApplicationName   = local.global_settings.locals.product_name
    Environment       = local.env_for_tags
    ResourceOwner     = local.global_settings.locals.team_name
    ProductFamilyName = local.global_settings.locals.product_name
  }

  # Additional security tags added at a later date by security/asset-tagging
  # team.
  extra_tags = {
    TeamName = local.global_settings.locals.team_name
  }

  # Note the "="; remote_state is configured on a per-env basis.
  remote_state_config = {
    backend = "s3"
    config = {
      bucket              = "${local.aws_account_id}.${local.sanitized_git_org}.${local.sanitized_project_name}"
      key                 = "${path_relative_to_include("root")}/terraform.tfstate"
      region              = local.default_aws_region
      encrypt             = true
      dynamodb_table      = "${local.aws_account_id}.${local.sanitized_git_org}.${local.sanitized_project_name}"
      profile             = local.default_aws_profile
      s3_bucket_tags      = local.default_tags
      dynamodb_table_tags = local.default_tags
    }
  }
}
