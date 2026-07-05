include "modules" {
  path   = "${get_repo_root()}/terraform/_global_settings/modules.hcl"
  expose = true
}

terraform {
  source = include.modules.locals.release_versions.modules.helpers.storage.source
}

inputs = {
  name_prefix = "forge-prod"
  aws_region  = "eu-west-1"
}
