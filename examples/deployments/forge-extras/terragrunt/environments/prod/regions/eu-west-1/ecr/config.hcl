locals {
  config       = yamldecode(file("config.yaml"))
  repositories = local.config.repositories
}
