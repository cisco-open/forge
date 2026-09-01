resource "kubernetes_cluster_role_v1" "impersonate" {
  metadata {
    name = "teleport-${var.namespace}-impersonate"
  }

  rule {
    api_groups = [""]
    resources  = ["users", "groups", "serviceaccounts"]
    verbs      = ["impersonate"]
  }

  rule {
    api_groups = ["authorization.k8s.io"]
    resources  = ["selfsubjectaccessreviews", "selfsubjectrulesreviews"]
    verbs      = ["create"]
  }

}
resource "kubernetes_cluster_role_v1" "pods" {
  metadata {
    name = "teleport-${var.namespace}-pods"
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "pods/log"]
    verbs      = ["get", "watch", "list"]
  }

  # Keep exec write access isolated from pod and pod-log read access.
  rule {
    api_groups = [""]
    resources  = ["pods/exec"]
    verbs      = ["get", "create"]
  }

}

resource "kubernetes_cluster_role_binding_v1" "impersonate" {
  metadata {
    name = "teleport-${var.namespace}-impersonate-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "teleport-${var.namespace}-impersonate"
  }

  subject {
    kind      = "Group"
    name      = "teleport-${var.namespace}"
    api_group = "rbac.authorization.k8s.io"
    namespace = var.namespace
  }
}

resource "kubernetes_role_binding_v1" "pods" {
  metadata {
    name      = "teleport-${var.namespace}-pods-binding"
    namespace = var.namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "teleport-${var.namespace}-pods"
  }

  subject {
    kind      = "Group"
    name      = "teleport-${var.namespace}"
    api_group = "rbac.authorization.k8s.io"
    namespace = var.namespace
  }
}
