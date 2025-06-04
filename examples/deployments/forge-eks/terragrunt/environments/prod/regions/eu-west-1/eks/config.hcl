locals {

  config = yamldecode(file(find_in_parent_folders("config.yaml")))

  cluster_name    = local.config.cluster_name
  cluster_version = local.config.cluster_version
  cluster_size    = local.config.cluster_size
  subnet_ids      = local.config.subnet_ids
  vpc_id          = local.config.vpc_id
}
