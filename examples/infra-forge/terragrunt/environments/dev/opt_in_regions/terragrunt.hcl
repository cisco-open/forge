# Get root module.
include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Global settings.
include "global" {
  path   = find_in_parent_folders("_global_settings/_global.hcl")
  expose = true
}

# Environment-wide settings.
include "env" {
  path   = find_in_parent_folders("_environment_wide_settings/_environment.hcl")
  expose = true
}

# Module-global settings (i.e. module inputs).
include "mod_global" {
  path   = find_in_parent_folders("_global_settings/opt_in_regions.hcl")
  expose = true
}

# Version of module to use.
locals {
  module_name     = "opt_in_regions"
  project         = include.global.locals.project_name
  env             = include.env.locals.env
  release_version = yamldecode(file("${get_repo_root()}/release_versions.yaml"))
  use_local_repos = local.release_version["metadata"]["use_local_repos"]
  module_root     = local.release_version["spec"]["iac"]["modules"][local.module_name]
  git_prefix      = "git::file://"
  module_base     = local.use_local_repos ? "${local.git_prefix}${get_repo_root()}/${local.module_root["local_path"]}" : local.module_root["repo"]
  module_version  = local.module_root["ref"]
  module_ref      = "${local.module_base}//modules/${local.module_name}?ref=${local.module_version}"
}

# Construct the terraform.source attribute using the source_base.
terraform {
  source = "${local.module_ref}"
}

# Remote state storage/locks.
remote_state {
  backend = "${include.env.locals.remote_state_config.backend}"
  config = {
    bucket              = "${include.env.locals.remote_state_config.config.bucket}"
    key                 = "${path_relative_to_include("root")}/terraform.tfstate"
    region              = "${include.env.locals.remote_state_config.config.region}"
    encrypt             = include.env.locals.remote_state_config.config.encrypt
    dynamodb_table      = "${include.env.locals.remote_state_config.config.dynamodb_table}"
    profile             = "${include.env.locals.remote_state_config.config.profile}"
    s3_bucket_tags      = "${include.env.locals.remote_state_config.config.s3_bucket_tags}"
    dynamodb_table_tags = "${include.env.locals.remote_state_config.config.dynamodb_table_tags}"
  }
}
