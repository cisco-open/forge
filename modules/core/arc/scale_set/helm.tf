resource "kubernetes_config_map" "hook_extension" {
  metadata {
    name      = "hook-extension-${var.scale_set_name}"
    namespace = var.namespace
  }

  data = {
    "container-podspec.yaml" = <<-EOT
      metadata:
        annotations:
          annotated-by: "extension"
        labels:
          labeled-by: "extension"
      spec:
        automountServiceAccountToken: true
        serviceAccountName: "${var.service_account}"
        securityContext:
          fsGroup: 123 # Group used by GitHub default agent image
        containers:
        - name: "$job" # Target the job container
      EOT
  }
}

resource "kubernetes_config_map" "hook_pre_post_job" {
  metadata {
    name      = "hook-pre-post-job-${var.scale_set_name}"
    namespace = var.namespace
  }

  data = {
    "job_started.sh"   = file("${path.module}/template_files/hook_job_started.tftpl")
    "job_completed.sh" = file("${path.module}/template_files/hook_job_completed.tftpl")
  }
}

resource "helm_release" "gha_runner_scale_set" {
  name      = var.release_name
  namespace = var.namespace
  chart     = var.chart_name
  version   = var.chart_version

  create_namespace = true

  values = [
    templatefile(
      "${path.module}/template_files/${var.scale_set_type}.yml.tftpl",
      {
        config_secret              = var.secret_name
        max_runners                = var.runner_size.max_runners
        min_runners                = var.runner_size.min_runners
        runner_group_name          = var.runner_group_name
        scale_set_name             = var.scale_set_name
        container_limits_cpu       = var.container_limits_cpu
        container_limits_memory    = var.container_limits_memory
        container_requests_cpu     = var.container_requests_cpu
        container_requests_memory  = var.container_requests_memory
        container_ecr_registries   = var.container_ecr_registries
        service_account            = var.service_account
        github_config_url          = local.github_config_url
        controller_namespace       = var.controller.namespace
        controller_service_account = var.controller.service_account
        container_actions_runner   = var.container_actions_runner
        runner_role                = aws_iam_role.runner_role.arn
      }
    )
  ]
  upgrade_install = true
  cleanup_on_fail = true
  timeout         = 1200
}
