locals {
  global_settings = read_terragrunt_config(find_in_parent_folders("_global_settings/_global.hcl"))

  environment = yamldecode(file(find_in_parent_folders("_environment.yaml")))

  # Environment name.
  env = local.environment.env

  # Default region in which we store critical infra such as secrets, DynamoDB
  # tables, etc.
  default_aws_region = local.environment.default_aws_region

  # AWS account associated with this environment.
  aws_account_id      = local.environment.aws_account_id
  aws_account_name    = "${local.global_settings.locals.aws_account_prefix}-${local.env}"
  default_aws_profile = "${local.aws_account_name}"

  # Sanitized values
  sanitized_project_name = replace(local.global_settings.locals.project_name, "_", "-")
  sanitized_git_org      = replace(local.global_settings.locals.git_org, "_", "-")

  # Default security tags.
  default_tags = {
    TeamName          = local.global_settings.locals.team_name
    ApplicationName   = local.global_settings.locals.product_name
    Environment       = local.env
    ResourceOwner     = local.global_settings.locals.team_name
    ProductFamilyName = local.global_settings.locals.product_name
  }

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
