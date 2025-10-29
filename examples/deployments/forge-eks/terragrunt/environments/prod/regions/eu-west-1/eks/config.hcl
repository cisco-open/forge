locals {

  config = yamldecode(file("config.yaml"))

  cluster_name                   = local.config.cluster_name
  cluster_version                = local.config.cluster_version
  cluster_size                   = local.config.cluster_size
  subnet_ids                     = local.config.subnet_ids
  vpc_id                         = local.config.vpc_id
  cluster_ami_filter             = local.config.cluster_ami_filter
  cluster_ami_owners             = local.config.cluster_ami_owners
  cluster_volume                 = local.config.cluster_volume
  cluster_endpoint_public_access = local.config.cluster_endpoint_public_access
  external_access_cidr_blocks    = local.config.external_access_cidr_blocks
  cluster_admin_role_arn         = local.config.cluster_admin_role_arn
}
