locals {
  global_data  = read_terragrunt_config(find_in_parent_folders("_global_settings/_global.hcl"))
  group_email  = local.global_data.locals.group_email
  team_name    = local.global_data.locals.team_name
  product_name = local.global_data.locals.product_name
  project_name = local.global_data.locals.project_name

  env_data            = read_terragrunt_config(find_in_parent_folders("_environment_wide_settings/_environment.hcl"))
  aws_account_id      = local.env_data.locals.aws_account_id
  default_aws_profile = local.env_data.locals.default_aws_profile

  region_data = read_terragrunt_config(find_in_parent_folders("_region_wide_settings/_region.hcl"))
  region      = local.region_data.locals.region_aws

  connector_data = read_terragrunt_config(find_in_parent_folders("microvm/config.hcl"))

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
    LastRevalidatedAt = "2026-08-07"
  }
}

inputs = {
  aws_profile = local.default_aws_profile
  aws_region  = local.region

  artifact_bucket_name    = "${local.aws_account_id}-forge-microvm-artifacts-${local.region}"
  artifact_retention_days = 30
  image_name_prefix       = "forge-gh-runner-ubuntu-arm64"

  ecr_repository_arns = [
    "arn:aws:ecr:${local.region}:${local.aws_account_id}:repository/actions-runner-base-image",
  ]

  network_connectors = local.connector_data.locals.network_connectors

  tags         = local.tags
  default_tags = local.default_tags
}
