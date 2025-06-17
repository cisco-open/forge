data "aws_caller_identity" "current" {}

data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
  depends_on = [
    time_sleep.wait_300_seconds,
    module.eks
  ]
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
  depends_on = [
    time_sleep.wait_300_seconds,
    module.eks
  ]
}
