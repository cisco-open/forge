locals {
  config                  = yamldecode(file("config.yml"))
  recorded_resource_types = local.config.recorded_resource_types
}
