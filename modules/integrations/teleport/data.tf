data "aws_eks_cluster" "cluster" {
  name = var.teleport_config.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.teleport_config.cluster_name
}

data "aws_caller_identity" "current" {}
