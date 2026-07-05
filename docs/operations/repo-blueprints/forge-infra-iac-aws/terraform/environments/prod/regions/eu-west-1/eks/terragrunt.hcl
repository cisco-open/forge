include "modules" {
  path   = "${get_repo_root()}/terraform/_global_settings/modules.hcl"
  expose = true
}

terraform {
  source = include.modules.locals.release_versions.modules.infra.eks.source
}

inputs = {
  cluster_name = "forge-prod-eu-west-1"
  region       = "eu-west-1"
}
