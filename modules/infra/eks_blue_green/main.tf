module "green" {
  source = "../eks"

  aws_profile = var.aws_profile
  aws_region  = var.aws_region

  cluster_name    = var.clusters.green.cluster_name
  cluster_version = var.clusters.green.cluster_version
  cluster_size    = var.clusters.green.cluster_size

  subnet_ids = var.clusters.green.subnet_ids
  vpc_id     = var.clusters.green.vpc_id

  cluster_ami_filter = var.clusters.green.cluster_ami_filter
  cluster_ami_owners = var.clusters.green.cluster_ami_owners

  cluster_tags = var.cluster_tags
  tags         = var.tags
  default_tags = var.default_tags
}

module "blue" {
  source = "../eks"

  aws_profile = var.aws_profile
  aws_region  = module.green.aws_region

  cluster_name    = var.clusters.blue.cluster_name
  cluster_version = var.clusters.blue.cluster_version
  cluster_size    = var.clusters.blue.cluster_size

  subnet_ids = var.clusters.blue.subnet_ids
  vpc_id     = var.clusters.blue.vpc_id

  cluster_ami_filter = var.clusters.blue.cluster_ami_filter
  cluster_ami_owners = var.clusters.blue.cluster_ami_owners

  cluster_tags = var.cluster_tags
  tags         = var.tags
  default_tags = var.default_tags
}
