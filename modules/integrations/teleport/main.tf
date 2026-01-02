module "tenant" {
  for_each = { for tenant in var.tenants : tenant => tenant }
  source   = "./tenant"

  namespace = each.value
}

resource "kubernetes_config_map_v1" "aws_auth_teleport" {
  count = length(var.tenants) > 0 ? 1 : 0
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = join("\n", [
      for tenant in var.tenants : <<EOT
- groups:
    - teleport-${tenant}
  rolearn: ${aws_iam_role.teleport_role.arn}
  username: teleport-${tenant}
EOT
    ])
  }
  depends_on = [
    module.tenant,
    aws_iam_role.teleport_role
  ]
}

resource "aws_eks_access_entry" "teleport" {
  cluster_name      = var.teleport_config.cluster_name
  principal_arn     = aws_iam_role.teleport_role.arn
  kubernetes_groups = ["teleport:kube-service:eks"]
  type              = "STANDARD"
  user_name         = "arn:aws:sts::${data.aws_caller_identity.current.account_id}:assumed-role/${var.teleport_config.cluster_name}-teleport/{{SessionName}}"
}
