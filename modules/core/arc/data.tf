data "aws_eks_cluster" "cluster" {
  name = var.eks_cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.eks_cluster_name
}

data "aws_subnet" "eks_subnets" {
  for_each = toset(data.aws_eks_cluster.cluster.vpc_config[0].subnet_ids)
  id       = each.value
}
