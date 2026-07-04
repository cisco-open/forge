locals {
  config          = yamldecode(file("config.yml"))
  replica_regions = local.config.replica_regions
}
