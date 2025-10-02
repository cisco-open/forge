# Root module (used for path resolution and remote state).
include "root" {
  path = find_in_parent_folders()
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

# Tenant-specific settings.
include "tenant_global" {
  path   = find_in_parent_folders("_global_settings/tenant.hcl")
  expose = true
}

# Version of module to use.
locals {
  module_name = "forge_runners"
  project     = include.global.locals.project_name
  env         = include.env.locals.env

  release_version_env     = get_env("RELEASE_VERSION_PATH", "")
  release_version_file    = length(trimspace(local.release_version_env)) > 0 ? local.release_version_env : "${get_repo_root()}/release_versions.yaml"
  release_version_content = file(local.release_version_file)
  release_version         = yamldecode(local.release_version_content)

  use_local_repos = local.release_version["metadata"]["use_local_repos"]
  module_root     = local.release_version["spec"]["iac"]["modules"][local.module_name]
  git_prefix      = "git::file://"

  module_base    = local.use_local_repos ? "${local.git_prefix}${get_repo_root()}/${local.module_root["local_path"]}" : local.module_root["repo"]
  module_version = local.module_root["ref"]
  module_ref     = local.use_local_repos ? "${local.module_base}//${local.module_root["module_path"]}" : "${local.module_base}//${local.module_root["module_path"]}?ref=${local.module_version}"
}

# Construct the terraform.source attribute using the source_base.
terraform {
  source = local.module_ref
}

# Remote state storage/locks.
remote_state {
  backend = include.env.locals.remote_state_config.backend

  config = {
    bucket              = include.env.locals.remote_state_config.config.bucket
    key                 = "${path_relative_to_include("root")}/terraform.tfstate"
    region              = include.env.locals.remote_state_config.config.region
    encrypt             = include.env.locals.remote_state_config.config.encrypt
    dynamodb_table      = include.env.locals.remote_state_config.config.dynamodb_table
    profile             = include.env.locals.remote_state_config.config.profile
    s3_bucket_tags      = include.env.locals.remote_state_config.config.s3_bucket_tags
    dynamodb_table_tags = include.env.locals.remote_state_config.config.dynamodb_table_tags
  }
}
