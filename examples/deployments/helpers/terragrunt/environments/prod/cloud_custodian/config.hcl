locals {
  config         = yamldecode(file("config.yml"))
  forge_role_arn = local.config.forge_role_arn
}
