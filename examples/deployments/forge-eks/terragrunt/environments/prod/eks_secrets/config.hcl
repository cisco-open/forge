locals {

  config = yamldecode(file("config.yaml"))

  replica_regions = local.config.replica_regions
}
