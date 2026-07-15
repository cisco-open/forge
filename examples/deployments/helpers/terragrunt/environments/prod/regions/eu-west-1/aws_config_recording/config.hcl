locals {
  config                  = yamldecode(file("config.yml"))
  delivery_bucket_name    = local.config.delivery_bucket_name
  recorded_resource_types = local.config.recorded_resource_types
}
