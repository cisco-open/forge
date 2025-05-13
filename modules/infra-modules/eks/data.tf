data "aws_eks_cluster" "cluster" {
  name       = var.cluster_name
  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "cluster" {
  name       = var.cluster_name
  depends_on = [module.eks]
}
