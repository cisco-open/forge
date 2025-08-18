data "aws_caller_identity" "current" {}

data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
  depends_on = [
    module.eks,
    data.external.update_kubeconfig
  ]
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
  depends_on = [
    module.eks,
    data.external.update_kubeconfig
  ]
}
