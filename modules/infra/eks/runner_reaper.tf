locals {
  runner_reaper_name = "arc-runner-reaper"
}

resource "kubernetes_namespace_v1" "runner_reaper" {
  count = var.runner_reaper.enabled ? 1 : 0

  metadata {
    name = var.runner_reaper.namespace
    labels = {
      "app.kubernetes.io/name"       = "arc-runner-reaper"
      "app.kubernetes.io/instance"   = local.runner_reaper_name
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }

  depends_on = [module.eks]
}

resource "kubernetes_config_map_v1" "runner_reaper" {
  count = var.runner_reaper.enabled ? 1 : 0

  metadata {
    name      = local.runner_reaper_name
    namespace = kubernetes_namespace_v1.runner_reaper[0].metadata[0].name
    labels = {
      "app.kubernetes.io/name"       = "arc-runner-reaper"
      "app.kubernetes.io/instance"   = local.runner_reaper_name
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }

  data = {
    "runner-reaper.sh" = file("${path.module}/templates/runner_reaper.sh")
  }
}

resource "kubernetes_service_account_v1" "runner_reaper" {
  count = var.runner_reaper.enabled ? 1 : 0

  metadata {
    name      = local.runner_reaper_name
    namespace = kubernetes_namespace_v1.runner_reaper[0].metadata[0].name
    labels = {
      "app.kubernetes.io/name"       = "arc-runner-reaper"
      "app.kubernetes.io/instance"   = local.runner_reaper_name
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }

  automount_service_account_token = true
}

resource "kubernetes_cluster_role_v1" "runner_reaper" {
  count = var.runner_reaper.enabled ? 1 : 0

  metadata {
    name = "${var.cluster_name}-${local.runner_reaper_name}"
    labels = {
      "app.kubernetes.io/name"       = "arc-runner-reaper"
      "app.kubernetes.io/instance"   = local.runner_reaper_name
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }

  rule {
    api_groups = ["actions.github.com"]
    resources  = ["autoscalingrunnersets"]
    verbs      = ["get", "list"]
  }

  rule {
    api_groups = ["actions.github.com"]
    resources  = ["ephemeralrunners"]
    verbs = var.runner_reaper.dry_run ? [
      "get",
      "list",
      ] : [
      "delete",
      "get",
      "list",
    ]
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods/exec"]
    verbs      = ["create"]
  }
}

resource "kubernetes_cluster_role_binding_v1" "runner_reaper" {
  count = var.runner_reaper.enabled ? 1 : 0

  metadata {
    name = "${var.cluster_name}-${local.runner_reaper_name}"
    labels = {
      "app.kubernetes.io/name"       = "arc-runner-reaper"
      "app.kubernetes.io/instance"   = local.runner_reaper_name
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.runner_reaper[0].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.runner_reaper[0].metadata[0].name
    namespace = kubernetes_service_account_v1.runner_reaper[0].metadata[0].namespace
  }
}

resource "kubernetes_cron_job_v1" "runner_reaper" {
  count = var.runner_reaper.enabled ? 1 : 0

  metadata {
    name      = local.runner_reaper_name
    namespace = kubernetes_namespace_v1.runner_reaper[0].metadata[0].name
    labels = {
      "app.kubernetes.io/name"       = "arc-runner-reaper"
      "app.kubernetes.io/instance"   = local.runner_reaper_name
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }

  spec {
    concurrency_policy            = "Forbid"
    failed_jobs_history_limit     = 3
    schedule                      = var.runner_reaper.schedule
    starting_deadline_seconds     = 120
    successful_jobs_history_limit = 3

    job_template {
      metadata {
        labels = {
          "app.kubernetes.io/name"     = "arc-runner-reaper"
          "app.kubernetes.io/instance" = local.runner_reaper_name
        }
      }

      spec {
        active_deadline_seconds = 600
        backoff_limit           = 0

        template {
          metadata {
            labels = {
              "app.kubernetes.io/name"     = "arc-runner-reaper"
              "app.kubernetes.io/instance" = local.runner_reaper_name
            }
          }

          spec {
            automount_service_account_token = true
            restart_policy                  = "Never"
            service_account_name            = kubernetes_service_account_v1.runner_reaper[0].metadata[0].name

            security_context {
              run_as_group    = 65532
              run_as_non_root = true
              run_as_user     = 65532

              seccomp_profile {
                type = "RuntimeDefault"
              }
            }

            container {
              name              = "reaper"
              image             = var.runner_reaper.image
              image_pull_policy = "IfNotPresent"
              command           = ["/bin/sh", "/opt/forge/runner-reaper.sh"]

              env {
                name  = "CLUSTER_NAME"
                value = var.cluster_name
              }

              env {
                name  = "DRY_RUN"
                value = tostring(var.runner_reaper.dry_run)
              }

              env {
                name  = "STALE_AFTER_SECONDS"
                value = tostring(var.runner_reaper.stale_after_seconds)
              }

              env {
                name  = "CONFIRMATION_DELAY_SECONDS"
                value = tostring(var.runner_reaper.confirmation_delay_seconds)
              }

              env {
                name  = "MAX_PROBES_PER_NAMESPACE"
                value = tostring(var.runner_reaper.max_probes_per_namespace)
              }

              env {
                name  = "MAX_PROBES_PER_RUN"
                value = tostring(var.runner_reaper.max_probes_per_run)
              }

              env {
                name  = "MAX_DELETIONS_PER_NAMESPACE"
                value = tostring(var.runner_reaper.max_deletions_per_namespace)
              }

              env {
                name  = "MAX_DELETIONS_PER_RUN"
                value = tostring(var.runner_reaper.max_deletions_per_run)
              }

              env {
                name  = "HOME"
                value = "/tmp"
              }

              resources {
                limits = {
                  cpu    = "100m"
                  memory = "128Mi"
                }
                requests = {
                  cpu    = "50m"
                  memory = "64Mi"
                }
              }

              security_context {
                allow_privilege_escalation = false
                read_only_root_filesystem  = true

                capabilities {
                  drop = ["ALL"]
                }
              }

              volume_mount {
                mount_path = "/opt/forge"
                name       = "script"
                read_only  = true
              }

              volume_mount {
                mount_path = "/tmp"
                name       = "tmp"
              }
            }

            volume {
              name = "script"

              config_map {
                default_mode = "0555"
                name         = kubernetes_config_map_v1.runner_reaper[0].metadata[0].name
              }
            }

            volume {
              name = "tmp"
              empty_dir {}
            }
          }
        }
      }
    }
  }

  depends_on = [module.self_managed_node_group]
}
