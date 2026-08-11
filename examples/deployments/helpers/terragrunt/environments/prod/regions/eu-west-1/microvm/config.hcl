locals {
  config             = yamldecode(file("config.yml"))
  network_connectors = local.config.network_connectors
}
