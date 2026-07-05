locals {
  release_versions = yamldecode(file("${get_repo_root()}/release_versions.yml"))
  tenant_module    = local.release_versions.modules.platform.forge_runners.source
}
