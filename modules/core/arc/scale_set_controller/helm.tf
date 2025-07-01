resource "helm_release" "gha_runner_scale_set_controller" {
  count     = var.migrate_arc_cluster == false ? 1 : 0
  name      = var.release_name
  namespace = var.namespace
  chart     = var.chart_name
  version   = var.chart_version

  create_namespace = true

  values = [
    templatefile(
      "${path.module}/template_files/values.yml.tftpl",
      {
        name      = var.controller_config.name
        namespace = var.namespace
      }
    )
  ]

  upgrade_install = true
  cleanup_on_fail = true
  timeout         = 1200

  depends_on = [kubernetes_secret.github_app]
}
