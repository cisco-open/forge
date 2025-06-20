resource "kubernetes_role" "k8s" {
  count = var.scale_set_type == "k8s" ? 1 : 0

  metadata {
    name      = var.service_account
    namespace = var.namespace
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "list", "create", "delete"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods/exec"]
    verbs      = ["get", "create"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods/log"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["batch"]
    resources  = ["jobs"]
    verbs      = ["get", "list", "create", "delete"]
  }

  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["create", "delete", "get", "list"]
  }
}

resource "kubernetes_role_binding" "k8s" {
  count = var.scale_set_type == "k8s" ? 1 : 0

  metadata {
    name      = var.service_account
    namespace = var.namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.k8s[0].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = var.service_account
    namespace = var.namespace
  }
}
