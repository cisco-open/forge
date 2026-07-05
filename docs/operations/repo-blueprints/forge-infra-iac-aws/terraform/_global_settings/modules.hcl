locals {
  release_versions = yamldecode(file("${get_repo_root()}/release_versions.yml"))
}
