locals {
  ecr_repository_regions = toset(var.forge.ecr_repositories.regions)
  ecr_provider_regions = toset(distinct(concat(
    var.forge.ecr_repositories.regions,
    var.forge.ecr_repositories.provider_regions,
  )))
}

module "ecr_repository_policy_by_region" {
  for_each = local.ecr_repository_regions
  source   = "./modules/ecr_repository_policy"

  providers = {
    aws = aws.by_region[each.key]
  }

  repository_names       = var.forge.ecr_repositories.names
  ecr_access_account_ids = var.forge.ecr_repositories.ecr_access_account_ids
}
