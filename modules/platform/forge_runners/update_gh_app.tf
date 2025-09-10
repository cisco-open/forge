resource "null_resource" "update_github_app_webhook" {
  triggers = {
    ghes_org       = var.ghes_org
    ghes_url       = var.ghes_url
    webhook_url    = try(module.ec2_runners[0].webhook_endpoint, "https://cisco-open.github.io/forge")
    secret         = try(random_id.random[0].hex, null)
    secret_version = data.aws_secretsmanager_secret_version.data_cicd_secrets["${local.cicd_secrets_prefix}github_actions_runners_app_key"].id
  }

  provisioner "local-exec" {
    environment = {
      CLIENT_ID = data.aws_secretsmanager_secret_version.data_cicd_secrets["${local.cicd_secrets_prefix}github_actions_runners_app_client_id"].secret_string
      PRIVATE_KEY = base64decode(
        data.aws_secretsmanager_secret_version.data_cicd_secrets["${local.cicd_secrets_prefix}github_actions_runners_app_key"].secret_string
      )
      WEBHOOK_URL = self.triggers.webhook_url
      SECRET      = self.triggers.secret
      GITHUB_API  = local.github_api
      PREFIX      = "${var.env}-${var.deployment_config.prefix}"
    }

    command = "${path.module}/scripts/generate_and_patch_github_app.sh"
  }

  depends_on = [
    data.aws_secretsmanager_secret_version.data_cicd_secrets,
  ]
}
