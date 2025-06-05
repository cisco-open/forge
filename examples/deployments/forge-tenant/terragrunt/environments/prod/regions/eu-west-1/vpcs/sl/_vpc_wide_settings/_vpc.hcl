locals {
  vpc = yamldecode(file("_vpc.yaml"))

  vpc_alias         = local.vpc.vpc_alias
  lambda_subnet_ids = local.vpc.lambda_subnet_ids
  vpc_id            = local.vpc.vpc_id
  subnet_ids        = local.vpc.subnet_ids
  cluster_name      = local.vpc.cluster_name
}
