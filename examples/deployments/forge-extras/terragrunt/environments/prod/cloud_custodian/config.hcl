locals {
  config         = yamldecode(file("config.yaml"))
  forge_role_arn = local.config.forge_role_arn
}
