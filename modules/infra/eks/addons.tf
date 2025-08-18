# Fetch the most recent version of the aws-ebs-csi-driver
data "aws_eks_addon_version" "aws_ebs_csi_driver" {
  addon_name         = "aws-ebs-csi-driver"
  kubernetes_version = var.cluster_version
}

# Fetch the most recent version of the eks-pod-identity-agent
data "aws_eks_addon_version" "eks_pod_identity_agent" {
  addon_name         = "eks-pod-identity-agent"
  kubernetes_version = var.cluster_version
}

# Fetch the most recent version of the CoreDNS
data "aws_eks_addon_version" "coredns" {
  addon_name         = "coredns"
  kubernetes_version = var.cluster_version
}

resource "aws_eks_addon" "aws_ebs_csi_driver" {
  cluster_name             = var.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = data.aws_eks_addon_version.aws_ebs_csi_driver.version
  service_account_role_arn = module.ebs_csi_irsa_role.arn
  timeouts {
    create = "60m"
    update = "60m"
    delete = "60m"
  }

  depends_on = [
    module.self_managed_node_group,
  ]
}

resource "aws_eks_addon" "eks_pod_identity_agent" {
  cluster_name  = var.cluster_name
  addon_name    = "eks-pod-identity-agent"
  addon_version = data.aws_eks_addon_version.eks_pod_identity_agent.version
  timeouts {
    create = "60m"
    update = "60m"
    delete = "60m"
  }

  configuration_values = jsonencode({
    agent = {
      additionalArgs = {
        "-b" : "169.254.170.23"
      }
    }
  })

  depends_on = [module.self_managed_node_group]
}

resource "aws_eks_addon" "coredns" {
  cluster_name  = var.cluster_name
  addon_name    = "coredns"
  addon_version = data.aws_eks_addon_version.coredns.version
  timeouts {
    create = "60m"
    update = "60m"
    delete = "60m"
  }

  depends_on = [module.self_managed_node_group]
}
