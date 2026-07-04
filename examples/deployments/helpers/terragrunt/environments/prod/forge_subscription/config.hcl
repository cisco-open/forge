locals {
  config = yamldecode(file("config.yml"))
  forge  = local.config.forge
}
