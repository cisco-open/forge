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


data "aws_iam_openid_connect_provider" "cluster" {
  url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}
