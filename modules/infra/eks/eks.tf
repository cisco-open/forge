data "aws_ami" "eks_default" {
  most_recent = true
  owners      = var.cluster_ami_owners

  filter {
    name   = "name"
    values = var.cluster_ami_filter
  }
}

module "ebs_csi_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "6.1.0"

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
  version = "21.1.0"

  name               = var.cluster_name
  kubernetes_version = var.cluster_version

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  addons = {
    kube-proxy = {}
  }

  endpoint_public_access = var.cluster_endpoint_public_access

  authentication_mode = "API_AND_CONFIG_MAP"

  access_entries = {
    super-admin = {
      principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/owner"

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

data "external" "update_kubeconfig" {
  depends_on = [module.eks]
  program = ["bash", "-c", <<EOT
    aws eks update-kubeconfig \
      --region '${var.aws_region}' \
      --name '${module.eks.cluster_name}' \
      --alias '${module.eks.cluster_name}-${var.aws_profile}-${var.aws_region}' \
      --profile '${var.aws_profile}' >/dev/null 2>&1

    echo '{
      "kubeconfig_alias":"'"${module.eks.cluster_name}-${var.aws_profile}-${var.aws_region}"'",
      "cluster_name":"'"${module.eks.cluster_name}"'"
    }'
  EOT
  ]
}
