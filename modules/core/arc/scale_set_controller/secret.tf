resource "kubernetes_namespace_v1" "controller_namespace" {
  count = var.migrate_arc_cluster == false ? 1 : 0
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_secret_v1" "github_app" {
  count = var.migrate_arc_cluster == false ? 1 : 0

  metadata {
    name      = var.release_name
    namespace = var.namespace
  }

  type = "generic"

  data_wo = {
    github_app_id              = ephemeral.aws_ssm_parameter.id_ssm.value
    github_app_installation_id = ephemeral.aws_ssm_parameter.installation_id_ssm.value
    github_app_private_key     = base64decode(ephemeral.aws_ssm_parameter.key_base64_ssm.value)
  }
  lifecycle {
    create_before_destroy = true
  }
  depends_on = [kubernetes_namespace_v1.controller_namespace]
}

ephemeral "aws_ssm_parameter" "id_ssm" {
  arn = var.github_app.id_ssm.arn
}

ephemeral "aws_ssm_parameter" "installation_id_ssm" {
  arn = var.github_app.installation_id_ssm.arn
}

ephemeral "aws_ssm_parameter" "key_base64_ssm" {
  arn = var.github_app.key_base64_ssm.arn
}
