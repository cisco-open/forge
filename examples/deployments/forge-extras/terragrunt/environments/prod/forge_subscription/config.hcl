locals {
  config = yamldecode(file("config.yaml"))
  forge  = local.config.forge
}
