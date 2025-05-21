# Region-wide settings.
include "region" {
  path   = find_in_parent_folders("_region_wide_settings/_region.hcl")
  expose = true
}

# VPC-wide settings.
include "vpc" {
  path   = find_in_parent_folders("_vpc_wide_settings/_vpc.hcl")
  expose = true
}

locals {
  # Aliases
  region_alias  = include.region.locals.region_alias
  vpc_alias     = include.vpc.locals.vpc_alias
  tenant_prefix = "${local.region_alias}-${local.vpc_alias}"

  tenants = [
    "forge"
  ]

  teleport_config = {
    cluster_name                = "forge-euw1-prod"
    teleport_iam_role_to_assume = "<ADD YOUR VALUE>" # e.g., "arn:aws:iam::123456789012:role/teleport-access"
  }
}
