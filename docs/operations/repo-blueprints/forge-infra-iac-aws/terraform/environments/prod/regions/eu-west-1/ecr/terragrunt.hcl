include "modules" {
  path   = "${get_repo_root()}/terraform/_global_settings/modules.hcl"
  expose = true
}

terraform {
  source = include.modules.locals.release_versions.modules.helpers.ecr.source
}

inputs = {
  repositories = [
    "forge/action-runner",
    "forge/pre-commit"
  ]
}
