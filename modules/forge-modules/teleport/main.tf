module "teleport" {
  for_each = { for tenant in var.tenants : tenant => tenant }
  source   = "./submodules/teleport"

  namespace       = each.value
  release_name    = "${each.value}-${var.tenant_prefix}"
  teleport_config = var.teleport_config

  tags = var.tags
}

resource "kubernetes_config_map" "aws_auth_teleport" {
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
  rolearn: ${module.teleport[tenant].iam_role_arn}
  username: teleport-${tenant}
EOT
    ])
  }
  depends_on = [module.teleport]
}
