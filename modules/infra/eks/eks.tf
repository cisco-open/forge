module "ebs_csi_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "6.4.0"

  name                  = "${var.cluster_name}-${var.aws_region}-ebs-csi"
  use_name_prefix       = false
  policy_name           = "${var.cluster_name}-${var.aws_region}-ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.15.1"

  name               = var.cluster_name
  kubernetes_version = var.cluster_version

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  addons = {
    kube-proxy = {}
  }

  endpoint_public_access = var.cluster_endpoint_public_access
  security_group_additional_rules = length(var.external_access_cidr_blocks) > 0 ? {
    external-access = {
      cidr_blocks = var.external_access_cidr_blocks
      description = "Allow external access to k8s api"
      from_port   = 443
      to_port     = 443
      protocol    = "TCP"
      type        = "ingress"
    }
  } : {}

  authentication_mode = "API_AND_CONFIG_MAP"

  access_entries = {
    super-admin = {
      principal_arn = var.cluster_admin_role_arn

      policy_associations = {
        this = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  cloudwatch_log_group_retention_in_days = 3

  tags = local.all_security_tags

  cluster_tags = var.cluster_tags
}

resource "null_resource" "wait_for_cluster" {
  triggers = {
    cluster_name = module.eks.cluster_name
  }

  provisioner "local-exec" {
    command = <<EOT
    # Wait until EKS API returns active
    aws eks wait cluster-active --name ${module.eks.cluster_name} --region ${var.aws_region} --profile '${var.aws_profile}'
    aws eks update-kubeconfig \
      --region '${var.aws_region}' \
      --name '${module.eks.cluster_name}' \
      --alias '${module.eks.cluster_name}-${var.aws_profile}-${var.aws_region}' \
      --profile '${var.aws_profile}' >/dev/null 2>&1
    EOT
  }
}

data "external" "update_kubeconfig" {
  depends_on = [null_resource.wait_for_cluster]
  program = ["bash", "-c", <<EOT
    aws eks update-kubeconfig \
      --region '${var.aws_region}' \
      --name '${var.cluster_name}' \
      --alias '${var.cluster_name}-${var.aws_profile}-${var.aws_region}' \
      --profile '${var.aws_profile}' >/dev/null 2>&1

    echo '{
      "kubeconfig_alias":"'"${var.cluster_name}-${var.aws_profile}-${var.aws_region}"'",
      "cluster_name":"'"${var.cluster_name}"'"
    }'
  EOT
  ]
}
