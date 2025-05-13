locals {
  # Project-wide settings (i.e. global across the various AWS accounts used in
  # the overall repo/project).
  global_data  = read_terragrunt_config(find_in_parent_folders("_global_settings/_global.hcl"))
  group_email  = local.global_data.locals.group_email
  project_name = local.global_data.locals.project_name

  # Environment-wide settings.
  env_data            = read_terragrunt_config(find_in_parent_folders("_environment_wide_settings/_environment.hcl"))
  default_aws_profile = local.env_data.locals.default_aws_profile
  aws_account_id      = local.env_data.locals.aws_account_id

  # Region-wide settings.
  region_data = read_terragrunt_config(find_in_parent_folders("_region_wide_settings/_region.hcl"))
  region      = local.region_data.locals.region_aws

  eks_settings_data = read_terragrunt_config(find_in_parent_folders("eks/config.hcl"))
}

inputs = {
  # Common values re-used throughout sub-modules. These are also used in things
  # like logs, determining which S3 buckets and/or paths to use for storing
  # build artifacts, etc.
  project_name   = local.project_name
  aws_profile    = local.default_aws_profile
  aws_account_id = local.aws_account_id

  # Let's centralize this into a common region.
  aws_region            = local.region
  cluster_name          = local.eks_settings_data.locals.cluster_name
  cluster_version       = local.eks_settings_data.locals.cluster_version
  cluster_size          = local.eks_settings_data.locals.cluster_size
  subnet_ids            = local.eks_settings_data.locals.subnet_ids
  vpc_id                = local.eks_settings_data.locals.vpc_id
  splunk_otel_collector = local.eks_settings_data.locals.splunk_otel_collector

  cluster_tags = {
    TeleportDiscovery = "ForgeCICD-MT"
  }
}
