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
  env_name            = local.env_data.locals.env
  default_aws_region  = local.env_data.locals.default_aws_region
  default_aws_profile = local.env_data.locals.default_aws_profile
  aws_account_id      = local.env_data.locals.aws_account_id

  # ─────────────────────────────────────────────────────────────────────────────
  # Region Settings
  # ─────────────────────────────────────────────────────────────────────────────
  region_data = read_terragrunt_config(find_in_parent_folders("_region_wide_settings/_region.hcl"))
  region      = local.region_data.locals.region_aws

  # ─────────────────────────────────────────────────────────────────────────────
  # Tags
  # ─────────────────────────────────────────────────────────────────────────────
  cluster_tags = {
    TeleportDiscovery = "ForgeCICD-MT" # <REPLACE WITH YOUR VALUE>
  }

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

  eks_settings_data = read_terragrunt_config(find_in_parent_folders("eks/config.hcl"))
}

inputs = {
  # Core Environment
  env            = local.env_name
  aws_account_id = local.aws_account_id
  aws_profile    = local.default_aws_profile
  aws_region     = local.region

  # EKS Cluster Settings
  cluster_name       = local.eks_settings_data.locals.cluster_name
  cluster_version    = local.eks_settings_data.locals.cluster_version
  cluster_size       = local.eks_settings_data.locals.cluster_size
  subnet_ids         = local.eks_settings_data.locals.subnet_ids
  vpc_id             = local.eks_settings_data.locals.vpc_id
  cluster_ami_filter = local.eks_settings_data.locals.cluster_ami_filter
  cluster_ami_owners = local.eks_settings_data.locals.cluster_ami_owners
  cluster_volume     = local.eks_settings_data.locals.cluster_volume

  # Misc
  cluster_tags = local.cluster_tags
  tags         = local.tags
  default_tags = local.default_tags
}
