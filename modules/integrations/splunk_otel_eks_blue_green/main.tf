module "splunk_otel_eks_green" {
  source = "../splunk_otel_eks"

  aws_profile = var.aws_profile
  aws_region  = var.aws_region

  cluster_name          = var.eks_cluster_names.green
  splunk_otel_collector = var.splunk_otel_collector

  default_tags = var.default_tags
}

module "splunk_otel_eks_blue" {
  source = "../splunk_otel_eks"

  aws_profile = var.aws_profile
  aws_region  = var.aws_region

  cluster_name          = var.eks_cluster_names.blue
  splunk_otel_collector = var.splunk_otel_collector

  default_tags = var.default_tags
}
