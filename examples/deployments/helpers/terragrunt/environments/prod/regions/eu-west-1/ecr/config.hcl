locals {
  config       = yamldecode(file("config.yml"))
  repositories = local.config.repositories
}
