resource "kubernetes_service_account_v1" "zombie_runner_cleanup" {
  count = var.migrate_arc_cluster == false ? 1 : 0
  metadata {
    name      = "zombie-runner-cleanup"
    namespace = var.controller_config.namespace
  }

  depends_on = [
    module.controller,
    module.scale_sets
  ]
}

resource "kubernetes_role_v1" "zombie_runner_cleanup" {
  count = var.migrate_arc_cluster == false ? 1 : 0
  metadata {
    name      = "zombie-runner-cleanup"
    namespace = var.controller_config.namespace
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "list"]
  }

  rule {
    api_groups = ["actions.github.com"]
    resources  = ["ephemeralrunners"]
    verbs      = ["get", "list", "delete", "watch"]
  }

  depends_on = [
    module.controller,
    module.scale_sets
  ]
}

resource "kubernetes_role_binding_v1" "zombie_runner_cleanup" {
  count = var.migrate_arc_cluster == false ? 1 : 0
  metadata {
    name      = "zombie-runner-cleanup"
    namespace = var.controller_config.namespace
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.zombie_runner_cleanup[0].metadata[0].name
    namespace = kubernetes_service_account_v1.zombie_runner_cleanup[0].metadata[0].namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.zombie_runner_cleanup[0].metadata[0].name
  }

  depends_on = [
    module.controller,
    module.scale_sets
  ]
}

resource "kubernetes_cron_job_v1" "zombie_runner_cleanup" {
  count = var.migrate_arc_cluster == false ? 1 : 0
  metadata {
    name      = "zombie-runner-cleanup"
    namespace = var.controller_config.namespace
  }

  spec {
    schedule = "*/10 * * * *"

    job_template {
      metadata {
        name = "zombie-runner-cleanup-job"
      }

      spec {
        template {
          metadata {
            labels = {
              job = "zombie-runner-cleanup"
            }
          }

          spec {
            service_account_name = kubernetes_service_account_v1.zombie_runner_cleanup[0].metadata[0].name
            restart_policy       = "OnFailure"

            container {
              name  = "zombie-runner-cleanup"
              image = "alpine:3"

              command = [
                "/bin/sh",
                "-c",
                templatefile("${path.module}/templates/zoombie_runner_cleanup.tpl", {
                  namespace = var.controller_config.namespace
                })
              ]
            }
          }
        }
      }
    }
  }

  depends_on = [
    module.controller,
    module.scale_sets
  ]
}
