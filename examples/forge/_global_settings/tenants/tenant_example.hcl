locals {
  # Project-wide settings (i.e. global across the various AWS accounts used in
  # the overall repo/project).
  global_data  = read_terragrunt_config(find_in_parent_folders("_global_settings/_global.hcl"))
  team_name    = local.global_data.locals.team_name
  project_name = local.global_data.locals.project_name
  product_name = local.global_data.locals.product_name

  # Environment-wide settings.
  env_data            = read_terragrunt_config(find_in_parent_folders("_environment_wide_settings/_environment.hcl"))
  env_name            = local.env_data.locals.env
  env_for_tags        = local.env_data.locals.env_for_tags
  default_aws_profile = local.env_data.locals.default_aws_profile
  aws_account_id      = local.env_data.locals.aws_account_id

  # Region-wide settings.
  region_data = read_terragrunt_config(find_in_parent_folders("_region_wide_settings/_region.hcl"))
  region      = local.region_data.locals.region_aws

  runner_settings_data = read_terragrunt_config(find_in_parent_folders("acgw/runner_settings.hcl"))
  tenant               = local.runner_settings_data.locals.tenant
}

inputs = {
  # Common values re-used throughout sub-modules. These are also used in things
  # like logs, determining which S3 buckets and/or paths to use for storing
  # build artifacts, etc.
  env            = local.env_name
  aws_account_id = local.aws_account_id
  aws_profile    = local.default_aws_profile

  # Let's centralize this into a common region.
  aws_region = local.region

  # Make sure the lambdas are launched in the appropriate subnet too.
  lambda_subnet_ids = local.runner_settings_data.locals.lambda_subnet_ids

  # VPC and subnet(s) in which our runners will be deployed. Obtained from
  vpc_id     = local.runner_settings_data.locals.vpc_id
  subnet_ids = local.runner_settings_data.locals.subnet_ids

  ec2_runner_specs  = local.runner_settings_data.locals.ec2_runner_specs
  ghes_url          = local.runner_settings_data.locals.ghes_url
  ghes_org          = local.runner_settings_data.locals.ghes_org
  tenant            = local.runner_settings_data.locals.tenant
  runner_group_name = local.runner_settings_data.locals.runner_group_name
  log_level         = local.runner_settings_data.locals.log_level

  arc_cluster_name = local.runner_settings_data.locals.arc_cluster_name
  arc_runner_specs = local.runner_settings_data.locals.arc_runner_specs

  tags = {
    ForgeCICDTenantName     = local.tenant.name
    ForgeCICDTenantVpcAlias = local.tenant.name
  }

  default_tags = {
    # Common tags we propagate project-wide.
    ApplicationName   = "${local.project_name}-${local.tenant.name}-${local.tenant.region_alias}-${local.tenant.vpc_alias}"
    Environment       = local.env_for_tags
    ResourceOwner     = local.team_name
    ProductFamilyName = local.product_name
  }
}
