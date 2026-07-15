locals {
  config      = yamldecode(file("config.yml"))
  host_groups = local.config.host_groups
}
