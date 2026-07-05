include "tenant" {
  path   = "${get_repo_root()}/terraform/_global_settings/tenant.hcl"
  expose = true
}

locals {
  config          = yamldecode(file("${get_terragrunt_dir()}/config.yml"))
  runner_settings = read_terragrunt_config("${get_terragrunt_dir()}/runner_settings.hcl").locals.runner_settings
}

terraform {
  source = include.tenant.locals.tenant_module
}

inputs = {
  tenant          = local.config.tenant
  runner_settings = local.runner_settings
}
