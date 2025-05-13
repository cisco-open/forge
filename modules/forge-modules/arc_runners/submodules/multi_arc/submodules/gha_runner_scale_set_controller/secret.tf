resource "kubernetes_namespace" "controller_namespace" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_secret" "github_app" {

  metadata {
    name      = var.release_name
    namespace = var.namespace
  }

  type = "generic"

  data = {
    github_app_id              = var.github_app.id
    github_app_installation_id = var.github_app.installation_id
    github_app_private_key     = base64decode(var.github_app.key_base64)
  }
  lifecycle {
    create_before_destroy = true
  }
  depends_on = [kubernetes_namespace.controller_namespace]
}
