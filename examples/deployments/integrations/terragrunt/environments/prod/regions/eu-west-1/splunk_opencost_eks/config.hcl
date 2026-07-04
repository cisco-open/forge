locals {
  config       = yamldecode(file("config.yml"))
  cluster_name = local.config.cluster_name
}
